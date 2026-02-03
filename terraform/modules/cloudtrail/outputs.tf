# =============================================================================
# CloudTrail Module - Outputs
# =============================================================================

output "trail_arn" {
  description = "ARN of the CloudTrail"
  value       = aws_cloudtrail.main.arn
}

output "trail_id" {
  description = "ID of the CloudTrail"
  value       = aws_cloudtrail.main.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}
