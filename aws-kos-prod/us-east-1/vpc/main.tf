module "vpc" {
  source = "../../../tf-modules/tf-vpc"

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short

  availability_zone_ids   = ["use1-az1", "use1-az3"]
  # Prod account block 10.0.64.0/20 (separate from kos-dev 10.0.16.0/20).
  vpc_cidr                = "10.0.64.0/21"
  create_internet_gateway = false
  create_nat_gateways     = false
  retention_in_days       = 7
}
