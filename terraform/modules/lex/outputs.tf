# =============================================================================
# Lex Module - Outputs
# =============================================================================

output "bot_id" {
  description = "ID of the Lex bot"
  value       = aws_lexv2models_bot.main.id
}

output "bot_name" {
  description = "Name of the Lex bot"
  value       = aws_lexv2models_bot.main.name
}
