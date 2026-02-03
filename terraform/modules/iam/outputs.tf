# =============================================================================
# IAM Module - Outputs
# =============================================================================

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda.name
}

output "connect_role_arn" {
  description = "ARN of the Connect service role"
  value       = aws_iam_role.connect.arn
}

output "connect_role_name" {
  description = "Name of the Connect service role"
  value       = aws_iam_role.connect.name
}

output "bedrock_role_arn" {
  description = "ARN of the Bedrock service role"
  value       = aws_iam_role.bedrock.arn
}

output "bedrock_role_name" {
  description = "Name of the Bedrock service role"
  value       = aws_iam_role.bedrock.name
}

output "lex_role_arn" {
  description = "ARN of the Lex service role"
  value       = aws_iam_role.lex.arn
}

output "lex_role_name" {
  description = "Name of the Lex service role"
  value       = aws_iam_role.lex.name
}

output "transcribe_role_arn" {
  description = "ARN of the Transcribe service role"
  value       = aws_iam_role.transcribe.arn
}

output "transcribe_role_name" {
  description = "Name of the Transcribe service role"
  value       = aws_iam_role.transcribe.name
}

output "events_role_arn" {
  description = "ARN of the CloudWatch Events role"
  value       = aws_iam_role.events.arn
}

output "events_role_name" {
  description = "Name of the CloudWatch Events role"
  value       = aws_iam_role.events.name
}
