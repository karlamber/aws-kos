output "cluster_endpoint" {
  value = module.rds.cluster_endpoint
}

output "cluster_port" {
  value = module.rds.cluster_port
}

output "database_name" {
  value = module.rds.database_name
}
