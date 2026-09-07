output "cloudwatch_logging_policy_arn" {
  description = "ARN of the shared CloudWatch logging policy (consumed by Lambda stacks)."
  value       = module.cloudwatch_logging.cloudwatch_logging_policy_arn
}
