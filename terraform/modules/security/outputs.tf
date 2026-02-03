# =============================================================================
# Security Module - Outputs
# =============================================================================

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "security_hub_account_id" {
  description = "Security Hub account ID"
  value       = var.enable_security_hub ? aws_securityhub_account.main[0].id : null
}

output "config_recorder_id" {
  description = "AWS Config recorder ID"
  value       = var.enable_aws_config ? aws_config_configuration_recorder.main[0].id : null
}

output "vpc_flow_log_id" {
  description = "VPC Flow Log ID"
  value       = var.enable_vpc_flow_logs ? aws_flow_log.vpc[0].id : null
}

output "flow_logs_log_group" {
  description = "CloudWatch log group for VPC Flow Logs"
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "config_bucket_name" {
  description = "S3 bucket name for AWS Config"
  value       = var.enable_aws_config ? aws_s3_bucket.config[0].id : null
}
