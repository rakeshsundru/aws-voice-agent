# =============================================================================
# Alerting Module - Outputs
# =============================================================================

output "sns_topic_arns" {
  description = "SNS topic ARNs by severity"
  value = {
    critical = aws_sns_topic.critical.arn
    warning  = aws_sns_topic.warning.arn
    info     = aws_sns_topic.info.arn
  }
}

output "critical_topic_arn" {
  description = "Critical alerts SNS topic ARN"
  value       = aws_sns_topic.critical.arn
}

output "warning_topic_arn" {
  description = "Warning alerts SNS topic ARN"
  value       = aws_sns_topic.warning.arn
}

output "info_topic_arn" {
  description = "Info alerts SNS topic ARN"
  value       = aws_sns_topic.info.arn
}
