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
