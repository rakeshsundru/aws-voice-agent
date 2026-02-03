# =============================================================================
# Polly Module - Outputs
# =============================================================================

output "config_parameter_name" {
  description = "SSM parameter name for Polly configuration"
  value       = aws_ssm_parameter.polly_config.name
}

output "config_parameter_arn" {
  description = "SSM parameter ARN for Polly configuration"
  value       = aws_ssm_parameter.polly_config.arn
}

output "voice_id" {
  description = "Configured Polly voice ID"
  value       = var.voice_id
}

output "engine" {
  description = "Configured Polly engine"
  value       = var.engine
}
