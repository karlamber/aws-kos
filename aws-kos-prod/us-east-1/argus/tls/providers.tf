provider "aws" {
  region              = var.region
  profile             = var.aws_profile
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Landscape     = var.landscape
      Environment   = var.env
      ProvisionedBy = "Python+Terraform"
    }
  }
}

provider "aws" {
  alias               = "route53"
  region              = "us-east-1"
  profile             = var.aws_profile
  allowed_account_ids = [var.route53_account_id]

  assume_role {
    role_arn = var.dns_manager_role_arn
  }

  default_tags {
    tags = {
      Landscape     = var.landscape
      Environment   = var.env
      ProvisionedBy = "Python+Terraform"
    }
  }
}
