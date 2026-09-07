locals {
  remote_state_bucket  = "s3-${var.landscape}-${var.env}-${var.region_short}-terraform-state"
  remote_state_region  = var.region
  remote_state_profile = var.aws_profile
}

data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket  = local.remote_state_bucket
    key     = "us-east-1/argus/rds/terraform.tfstate"
    region  = local.remote_state_region
    profile = local.remote_state_profile
  }
}
