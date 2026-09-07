locals {
  app_alias = "argus"
}

module "api_gateway" {
  source = "../../../../tf-modules/tf-apigw"

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short

  app_alias   = local.app_alias
  detail      = "api"
  description = "HTTP API for Argus SPA (/api) -> argus-api-lambda"

  lambda_function_name = data.terraform_remote_state.argus_api_lambda.outputs.lambda_function_name
  lambda_invoke_arn    = data.terraform_remote_state.argus_api_lambda.outputs.lambda_function_invoke_arn

  enable_access_logs        = true
  access_log_retention_days = 14

  jwt_authorizer = {
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${data.terraform_remote_state.cognito.outputs.user_pool_ids["employees"]}"
    audience = [data.terraform_remote_state.cognito.outputs.app_client_ids["argus"]]
  }
  default_route_authorization_type = "JWT"
  authorized_route_keys            = []
}
