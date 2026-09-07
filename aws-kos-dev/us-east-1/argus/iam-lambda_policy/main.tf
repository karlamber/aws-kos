module "iam_lambda_policy" {
  source = "../../../../tf-modules/tf-iam-lambda-policy"

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short

  app_alias = "argus"
}
