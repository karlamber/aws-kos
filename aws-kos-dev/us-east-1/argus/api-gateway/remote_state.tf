locals {
  remote_state_bucket  = "s3-${var.landscape}-${var.env}-${var.region_short}-terraform-state"
  remote_state_region  = var.region
  remote_state_profile = var.aws_profile
}

data "terraform_remote_state" "argus_api_lambda" {
  backend = "s3"
  config = {
    bucket  = local.remote_state_bucket
    key     = "us-east-1/argus/lambda-argus_api/terraform.tfstate"
    region  = local.remote_state_region
    profile = local.remote_state_profile
  }
}

data "terraform_remote_state" "cognito" {
  backend = "s3"
  config = {
    bucket  = local.remote_state_bucket
    key     = "us-east-1/cognito/terraform.tfstate"
    region  = local.remote_state_region
    profile = local.remote_state_profile
  }
}
