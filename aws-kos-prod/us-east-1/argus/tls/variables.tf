variable "env" {
  type        = string
  description = "Environment acronym (dev, prod)."
}

variable "account_name" {
  type        = string
  description = "AWS account alias used in naming."
}

variable "account_id" {
  type        = string
  description = "AWS account ID."
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile for provider and remote state."
}

variable "landscape" {
  type        = string
  description = "Landscape name (kos)."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "region_short" {
  type        = string
  description = "Short region code for resource naming (e.g. ue1)."
}

variable "route53_account_id" {
  type        = string
  description = "Account ID that owns the Route53 hosted zone (mgmt)."
}

variable "dns_manager_role_arn" {
  type        = string
  description = "IAM role ARN to assume for Route53 DNS management."
}
