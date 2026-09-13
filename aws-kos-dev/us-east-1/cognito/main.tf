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
      supported_identity_providers = ["COGNITO", "EntraID"]
      saml_provider_name           = "EntraID"
      saml_metadata_document_url   = "https://login.microsoftonline.com/dc49ec0c-b19b-4db9-9377-9434911623d2/federationmetadata/2007-06/federationmetadata.xml?appid=1f5b916d-ce32-46db-9e2b-467b97b55a57"
      attribute_mapping = {
        email       = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
        given_name  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"
        family_name = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"
      }
    }
  }
}
