# =============================================================================
# KMS Module - Outputs
# =============================================================================

output "key_arns" {
  description = "Map of KMS key ARNs by service type"
  value = var.enable_encryption ? {
    for key_type in ["s3", "lambda", "cloudwatch", "connect", "bedrock", "neptune", "transcribe"] :
    key_type => aws_kms_key.keys[key_type].arn
  } : {}
}

output "key_ids" {
  description = "Map of KMS key IDs by service type"
  value = var.enable_encryption ? {
    for key_type in ["s3", "lambda", "cloudwatch", "connect", "bedrock", "neptune", "transcribe"] :
    key_type => aws_kms_key.keys[key_type].key_id
  } : {}
}

output "key_aliases" {
  description = "Map of KMS key aliases by service type"
  value = var.enable_encryption ? {
    for key_type in ["s3", "lambda", "cloudwatch", "connect", "bedrock", "neptune", "transcribe"] :
    key_type => aws_kms_alias.keys[key_type].name
  } : {}
}

output "default_key_arn" {
  description = "ARN of the default KMS key"
  value       = var.enable_encryption ? aws_kms_key.default[0].arn : null
}

output "default_key_id" {
  description = "ID of the default KMS key"
  value       = var.enable_encryption ? aws_kms_key.default[0].key_id : null
}
