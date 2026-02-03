# =============================================================================
# Lambda Module - Outputs
# =============================================================================

output "orchestrator_function_name" {
  description = "Name of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.function_name
}

output "orchestrator_function_arn" {
  description = "ARN of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.arn
}

output "orchestrator_function_invoke_arn" {
  description = "Invoke ARN of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.invoke_arn
}

output "orchestrator_function_version" {
  description = "Version of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.version
}

output "orchestrator_function_qualified_arn" {
  description = "Qualified ARN of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.qualified_arn
}

output "orchestrator_alias_arn" {
  description = "ARN of the orchestrator Lambda alias"
  value       = aws_lambda_alias.orchestrator.arn
}

output "orchestrator_alias_invoke_arn" {
  description = "Invoke ARN of the orchestrator Lambda alias"
  value       = aws_lambda_alias.orchestrator.invoke_arn
}

output "integration_function_name" {
  description = "Name of the integration Lambda function"
  value       = aws_lambda_function.integration.function_name
}

output "integration_function_arn" {
  description = "ARN of the integration Lambda function"
  value       = aws_lambda_function.integration.arn
}

output "integration_function_invoke_arn" {
  description = "Invoke ARN of the integration Lambda function"
  value       = aws_lambda_function.integration.invoke_arn
}

output "integration_alias_arn" {
  description = "ARN of the integration Lambda alias"
  value       = aws_lambda_alias.integration.arn
}

output "layer_arn" {
  description = "ARN of the Lambda dependencies layer"
  value       = aws_lambda_layer_version.dependencies.arn
}

output "layer_version" {
  description = "Version of the Lambda dependencies layer"
  value       = aws_lambda_layer_version.dependencies.version
}

output "orchestrator_log_group_name" {
  description = "Name of the orchestrator CloudWatch log group"
  value       = aws_cloudwatch_log_group.orchestrator.name
}

output "orchestrator_log_group_arn" {
  description = "ARN of the orchestrator CloudWatch log group"
  value       = aws_cloudwatch_log_group.orchestrator.arn
}

output "integration_log_group_name" {
  description = "Name of the integration CloudWatch log group"
  value       = aws_cloudwatch_log_group.integration.name
}

output "integration_log_group_arn" {
  description = "ARN of the integration CloudWatch log group"
  value       = aws_cloudwatch_log_group.integration.arn
}

output "alarm_arns" {
  description = "Map of Lambda alarm ARNs"
  value = {
    errors    = aws_cloudwatch_metric_alarm.orchestrator_errors.arn
    duration  = aws_cloudwatch_metric_alarm.orchestrator_duration.arn
    throttles = aws_cloudwatch_metric_alarm.orchestrator_throttles.arn
  }
}

output "dlq_arns" {
  description = "Map of Dead Letter Queue ARNs"
  value = var.enable_dlq ? {
    orchestrator = aws_sqs_queue.orchestrator_dlq[0].arn
    integration  = aws_sqs_queue.integration_dlq[0].arn
  } : {}
}

output "dlq_urls" {
  description = "Map of Dead Letter Queue URLs"
  value = var.enable_dlq ? {
    orchestrator = aws_sqs_queue.orchestrator_dlq[0].url
    integration  = aws_sqs_queue.integration_dlq[0].url
  } : {}
}

output "dlq_names" {
  description = "Map of Dead Letter Queue names"
  value = var.enable_dlq ? {
    orchestrator = aws_sqs_queue.orchestrator_dlq[0].name
    integration  = aws_sqs_queue.integration_dlq[0].name
  } : {}
}
