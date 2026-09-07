terraform {
  required_version = "~> 1.15.0"

  backend "s3" {
    encrypt      = true
    use_lockfile = true
    # bucket, key, region, and profile are set in backend.hcl at init time.
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
