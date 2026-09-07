output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "private_security_group_id" {
  value = module.vpc.private_security_group_id
}

output "isolated_subnet_ids" {
  value = module.vpc.isolated_subnet_ids
}

output "isolated_security_group_id" {
  value = module.vpc.isolated_security_group_id
}

output "availability_zone_ids" {
  value = module.vpc.availability_zone_ids
}
