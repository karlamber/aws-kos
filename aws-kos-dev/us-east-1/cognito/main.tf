module "cognito" {
  source = "../../../tf-modules/tf-cognito"

  region       = var.region
  account_id   = var.account_id
  env          = var.env
  landscape    = var.landscape
  region_short = var.region_short

  user_pools = {
    employees = { detail = "employees" }
  }

  custom_sign_in_attributes = {
    employees = [
      {
        name                = "roles"
        attribute_data_type = "String"
        required            = false
        mutable             = true
        min_length          = 0
        max_length          = 2048
      }
    ]
  }

  applications = {
    argus = {
      user_pool                    = "employees"
      name                         = "argus-authn"
      domain                       = "argus-authn-${var.env}"
      allow_admin_create_user_only = true
      callback_urls = [
        "http://localhost:9000/auth/callback",
        "https://argus-${var.env}.fifty9.net/auth/callback",
      ]
      logout_urls = [
        "http://localhost:9000/login",
        "https://argus-${var.env}.fifty9.net/login",
      ]
      allowed_oauth_flows          = ["code"]
      allowed_oauth_scopes         = ["openid", "email", "profile"]
      supported_identity_providers = ["COGNITO"]
      attribute_mapping = {
        email       = "email"
        given_name  = "given_name"
        family_name = "family_name"
      }
    }
  }
}
