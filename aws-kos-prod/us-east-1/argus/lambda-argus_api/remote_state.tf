locals {
  remote_state_bucket  = "s3-${var.landscape}-${var.env}-${var.region_short}-terraform-state"
  remote_state_region  = var.region
  remote_state_profile = var.aws_profile
}

data "terraform_remote_state" "lambda_policy" {
  backend = "s3"
  config = {
    bucket  = local.remote_state_bucket
    key     = "us-east-1/argus/iam-lambda_policy/terraform.tfstate"
    region  = local.remote_state_region
    profile = local.remote_state_profile
  }
}

data "terraform_remote_state" "cloudwatch_logging" {
  backend = "s3"
  config = {
    bucket  = local.remote_state_bucket
    key     = "us-east-1/cloudwatch_logging/terraform.tfstate"
    region  = local.remote_state_region
    profile = local.remote_state_profile
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket  = local.remote_state_bucket
    key     = "us-east-1/vpc/terraform.tfstate"
    region  = local.remote_state_region
    profile = local.remote_state_profile
  }
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

data "terraform_remote_state" "cognito" {
  backend = "s3"
  config = {
    bucket  = local.remote_state_bucket
    key     = "us-east-1/cognito/terraform.tfstate"
    region  = local.remote_state_region
    profile = local.remote_state_profile
  }
}
