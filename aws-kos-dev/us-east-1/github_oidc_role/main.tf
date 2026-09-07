module "github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "5.60.0"

  name = "role-${var.landscape}-${var.env}-${var.region_short}-github_oidc"

  # From account.json / account.local.json (do not hardcode GitHub org/repo node IDs).
  subjects = var.oidc_subjects

  policies = {
    AmazonS3FullAccess   = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    CloudFrontFullAccess = "arn:aws:iam::aws:policy/CloudFrontFullAccess"
    AWSLambda_FullAccess = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
  }
}
