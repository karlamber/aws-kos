locals {
  app_alias = "argus"
}

module "ssm_param" {
  source = "../../../../tf-modules/tf-ssm_param"

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short

  parameters = [
    {
      comp        = "AURORA"
      app_alias   = upper(local.app_alias)
      name        = "WRITE_DB_HOST"
      value       = data.terraform_remote_state.rds.outputs.cluster_endpoint
      type        = "String"
      description = "AuroraDB Host used to connect to Argus DB for write"
    },
    {
      comp        = "AURORA"
      app_alias   = upper(local.app_alias)
      name        = "USERNAME"
      value       = "${local.app_alias}_service_acct"
      type        = "String"
      description = "Non DBO username for argus database"
    },
    {
      comp        = "AURORA"
      app_alias   = upper(local.app_alias)
      name        = "PASSWORD"
      value       = "<SEED_OUTSIDE_TERRAFORM>"
      type        = "SecureString"
      description = "Non DBO password for argus database"
    },
    {
      comp        = "ENV"
      app_alias   = upper(local.app_alias)
      name        = "LOG_LEVEL"
      value       = "debug"
      type        = "String"
      description = "Log level for argus"
    },
  ]
}
