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

variable "artifact_bucket" {
  type        = string
  description = "Shared S3 bucket that holds the Lambda deployment zip."
}
