output "user_pool_ids" {
  value = module.cognito.user_pool_ids
}

output "app_client_ids" {
  value = module.cognito.app_client_ids
}

output "cognito_domain_urls" {
  value = module.cognito.cognito_domain_urls
}
