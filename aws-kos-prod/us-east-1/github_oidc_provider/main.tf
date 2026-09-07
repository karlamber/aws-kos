module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "5.60.0"

  tags = {
    Name = "provider-${var.landscape}-${var.env}-${var.region_short}-github_oidc"
  }
}
