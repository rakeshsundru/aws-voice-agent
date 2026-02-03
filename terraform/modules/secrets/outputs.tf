# =============================================================================
# Secrets Module - Outputs
# =============================================================================

output "config_secret_arn" {
  description = "ARN of the voice agent config secret"
  value       = aws_secretsmanager_secret.voice_agent_config.arn
}

output "config_secret_name" {
  description = "Name of the voice agent config secret"
  value       = aws_secretsmanager_secret.voice_agent_config.name
}

output "api_keys_secret_arn" {
  description = "ARN of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.arn
}

output "api_keys_secret_name" {
  description = "Name of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.name
}

output "database_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = var.neptune_enabled ? aws_secretsmanager_secret.database_credentials[0].arn : null
}

output "database_secret_name" {
  description = "Name of the database credentials secret"
  value       = var.neptune_enabled ? aws_secretsmanager_secret.database_credentials[0].name : null
}

output "secrets_access_policy_arn" {
  description = "ARN of the IAM policy for secrets access"
  value       = aws_iam_policy.secrets_access.arn
}

output "secret_arns" {
  description = "Map of all secret ARNs"
  value = {
    config   = aws_secretsmanager_secret.voice_agent_config.arn
    api_keys = aws_secretsmanager_secret.api_keys.arn
    database = var.neptune_enabled ? aws_secretsmanager_secret.database_credentials[0].arn : null
  }
}
