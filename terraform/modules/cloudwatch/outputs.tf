# =============================================================================
# CloudWatch Module - Outputs
# =============================================================================

output "lambda_log_group_name" {
  description = "Name of the Lambda log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "lambda_log_group_arn" {
  description = "ARN of the Lambda log group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

output "connect_log_group_name" {
  description = "Name of the Connect log group"
  value       = aws_cloudwatch_log_group.connect.name
}

output "connect_log_group_arn" {
  description = "ARN of the Connect log group"
  value       = aws_cloudwatch_log_group.connect.arn
}

output "voice_agent_log_group_name" {
  description = "Name of the voice agent log group"
  value       = aws_cloudwatch_log_group.voice_agent.name
}

output "voice_agent_log_group_arn" {
  description = "ARN of the voice agent log group"
  value       = aws_cloudwatch_log_group.voice_agent.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = var.dashboard_enabled ? aws_cloudwatch_dashboard.main[0].dashboard_name : null
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = var.dashboard_enabled ? aws_cloudwatch_dashboard.main[0].dashboard_arn : null
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = var.dashboard_enabled ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = local.sns_topic_arn
}

output "alarm_arns" {
  description = "Map of CloudWatch alarm ARNs"
  value = {
    high_error_rate = aws_cloudwatch_metric_alarm.high_error_rate.arn
    high_latency    = aws_cloudwatch_metric_alarm.high_latency.arn
    high_concurrency = aws_cloudwatch_metric_alarm.high_concurrency.arn
    lambda_throttles = aws_cloudwatch_metric_alarm.lambda_throttles.arn
  }
}

output "log_metric_filter_names" {
  description = "Names of log metric filters"
  value = {
    error_count = aws_cloudwatch_log_metric_filter.error_count.name
    cold_start  = aws_cloudwatch_log_metric_filter.cold_start.name
    timeout     = aws_cloudwatch_log_metric_filter.timeout.name
  }
}
