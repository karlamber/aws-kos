module "rds" {
  source = "../../../../tf-modules/tf-rds"

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short

  app_alias               = "argus"
  subnet_tier             = "isolated"
  database_name           = "argus"
  engine                  = "aurora-postgresql"
  engine_version          = "17.4"
  master_username         = "postgres"
  storage_encrypted       = true
  create_kms_key          = false
  subnet_ids              = data.terraform_remote_state.vpc.outputs.isolated_subnet_ids
  vpc_security_group_ids  = [data.terraform_remote_state.vpc.outputs.isolated_security_group_id]
  port                    = 5432
  serverless_min_capacity = 0
  serverless_max_capacity = 1
  deletion_protection     = false
  availability_zone_ids   = data.terraform_remote_state.vpc.outputs.availability_zone_ids
  create_parameter_group  = false
  parameter_group_family  = "aurora-postgresql17"
  backup_retention_period = 7
}
