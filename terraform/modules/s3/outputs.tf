# =============================================================================
# S3 Module - Outputs
# =============================================================================

output "bucket_names" {
  description = "Map of bucket names by type"
  value = {
    for key, config in local.bucket_configs :
    key => aws_s3_bucket.buckets[key].id
  }
}

output "bucket_arns" {
  description = "Map of bucket ARNs by type"
  value = {
    for key, config in local.bucket_configs :
    key => aws_s3_bucket.buckets[key].arn
  }
}

output "bucket_domain_names" {
  description = "Map of bucket domain names by type"
  value = {
    for key, config in local.bucket_configs :
    key => aws_s3_bucket.buckets[key].bucket_domain_name
  }
}

output "bucket_regional_domain_names" {
  description = "Map of bucket regional domain names by type"
  value = {
    for key, config in local.bucket_configs :
    key => aws_s3_bucket.buckets[key].bucket_regional_domain_name
  }
}

output "recordings_bucket_name" {
  description = "Name of the recordings bucket"
  value       = aws_s3_bucket.buckets["recordings"].id
}

output "recordings_bucket_arn" {
  description = "ARN of the recordings bucket"
  value       = aws_s3_bucket.buckets["recordings"].arn
}

output "transcripts_bucket_name" {
  description = "Name of the transcripts bucket"
  value       = aws_s3_bucket.buckets["transcripts"].id
}

output "transcripts_bucket_arn" {
  description = "ARN of the transcripts bucket"
  value       = aws_s3_bucket.buckets["transcripts"].arn
}

output "artifacts_bucket_name" {
  description = "Name of the artifacts bucket"
  value       = aws_s3_bucket.buckets["artifacts"].id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts bucket"
  value       = aws_s3_bucket.buckets["artifacts"].arn
}

output "access_logs_bucket_name" {
  description = "Name of the access logs bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].id : null
}

output "access_logs_bucket_arn" {
  description = "ARN of the access logs bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].arn : null
}
