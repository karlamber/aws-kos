locals {
  app_alias       = "argus"
  detail          = "argus_api"
  description     = "Argus CMDB API Lambda (argus-api-lambda)"
  artifact_bucket = var.artifact_bucket
  artifact_key    = "${local.app_alias}/${var.env}/${local.app_alias}-${local.detail}.zip"
}

module "lambda_argus_api" {
  source = "../../../../tf-modules/tf-lambda"

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short

  cloudwatch_logging_policy = data.terraform_remote_state.cloudwatch_logging.outputs.cloudwatch_logging_policy_arn
  policy-std_lambda         = data.terraform_remote_state.lambda_policy.outputs.std_lambda

  vpc_config = {
    subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    security_group_ids = [data.terraform_remote_state.vpc.outputs.private_security_group_id]
  }

  config = {
    app_alias             = local.app_alias
    detail                = local.detail
    description           = local.description
    architectures         = ["x86_64"]
    handler               = "handler.handler"
    memory_size           = 256
    package_type          = "Zip"
    runtime               = "nodejs24.x"
    timeout               = 30
    application_log_level = "INFO"
    system_log_level      = "INFO"
    log_format            = "JSON"
    s3_bucket             = local.artifact_bucket
    s3_key                = local.artifact_key
    environment = {
      variables = {
        PGHOST                     = data.terraform_remote_state.rds.outputs.cluster_endpoint
        PGPORT                     = tostring(data.terraform_remote_state.rds.outputs.cluster_port)
        PGDATABASE                 = data.terraform_remote_state.rds.outputs.database_name
        PGUSER                     = "argus_lambda"
        PG_SSL                     = "true"
        PG_SSL_REJECT_UNAUTHORIZED = "false"
        PGPASSWORD                 = "<SEED_VIA_SSM_OR_CONSOLE>"
        AUTH_MODE                  = "cognito"
        CORS_ORIGIN                = "https://argus-${var.env}.fifty9.net"
        COGNITO_USER_POOL_ID       = data.terraform_remote_state.cognito.outputs.user_pool_ids["employees"]
        COGNITO_APP_CLIENT_ID      = data.terraform_remote_state.cognito.outputs.app_client_ids["argus"]
        COGNITO_ISSUER             = "https://cognito-idp.${var.region}.amazonaws.com/${data.terraform_remote_state.cognito.outputs.user_pool_ids["employees"]}"
        COGNITO_DOMAIN_URL         = data.terraform_remote_state.cognito.outputs.cognito_domain_urls["employees"]
        ADMIN_ROLE_CLAIM_VALUE     = "admin"
        APP_EDIT_ROLE_CLAIM_VALUE  = "app-edit"
        VIEWER_ROLE_CLAIM_VALUE    = "viewer"
        LOG_LEVEL                  = "info"
        SERVICE_NAME               = "argus-api"
        ENV_NAME                   = var.env
      }
    }
  }

  api_gateway_triggers = []
  sqs_triggers         = []
  s3_triggers          = []
  lambda_destinations  = {}

  custom_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaVPCAccess"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
        ]
        Resource = "*"
      },
      {
        Sid      = "ReadDeploymentPackage"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "arn:aws:s3:::${local.artifact_bucket}/*"
      }
    ]
  }
}
