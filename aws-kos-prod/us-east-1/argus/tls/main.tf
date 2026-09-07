module "tls" {
  source = "../../../../tf-modules/tf-tls"

  providers = {
    aws         = aws
    aws.route53 = aws.route53
  }

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short

  app_alias        = "argus"
  domain_name      = "argus-${var.env}.fifty9.net"
  hosted_zone_name = "fifty9.net"
}
