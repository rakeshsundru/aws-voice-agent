# =============================================================================
# Backup Module - Outputs
# =============================================================================

output "vault_arn" {
  description = "ARN of the backup vault"
  value       = aws_backup_vault.main.arn
}

output "vault_name" {
  description = "Name of the backup vault"
  value       = aws_backup_vault.main.name
}

output "plan_arn" {
  description = "ARN of the backup plan"
  value       = aws_backup_plan.main.arn
}

output "plan_id" {
  description = "ID of the backup plan"
  value       = aws_backup_plan.main.id
}

output "backup_role_arn" {
  description = "ARN of the backup IAM role"
  value       = aws_iam_role.backup.arn
}

output "backup_bucket_name" {
  description = "Name of the backup S3 bucket"
  value       = var.create_backup_bucket ? aws_s3_bucket.backup[0].id : null
}

output "backup_bucket_arn" {
  description = "ARN of the backup S3 bucket"
  value       = var.create_backup_bucket ? aws_s3_bucket.backup[0].arn : null
}

output "notification_topic_arn" {
  description = "ARN of backup notification SNS topic"
  value       = var.sns_topic_arn != null ? var.sns_topic_arn : aws_sns_topic.backup_notifications[0].arn
}
