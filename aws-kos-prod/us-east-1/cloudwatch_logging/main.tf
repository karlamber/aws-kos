module "cloudwatch_logging" {
  source = "../../../tf-modules/tf-cloudwatch"

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short
}
