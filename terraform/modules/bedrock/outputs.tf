# =============================================================================
# Bedrock Module - Outputs
# =============================================================================

output "guardrail_id" {
  description = "ID of the Bedrock guardrail"
  value       = var.guardrails_enabled ? aws_bedrock_guardrail.main[0].guardrail_id : null
}

output "guardrail_arn" {
  description = "ARN of the Bedrock guardrail"
  value       = var.guardrails_enabled ? aws_bedrock_guardrail.main[0].guardrail_arn : null
}

output "guardrail_version" {
  description = "Version of the Bedrock guardrail"
  value       = var.guardrails_enabled ? aws_bedrock_guardrail_version.main[0].version : null
}

output "knowledge_base_id" {
  description = "ID of the Bedrock knowledge base"
  value       = var.knowledge_base != null && var.knowledge_base.enabled ? aws_bedrockagent_knowledge_base.main[0].id : null
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock knowledge base"
  value       = var.knowledge_base != null && var.knowledge_base.enabled ? aws_bedrockagent_knowledge_base.main[0].arn : null
}

output "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection"
  value       = var.knowledge_base != null && var.knowledge_base.enabled ? aws_opensearchserverless_collection.knowledge_base[0].arn : null
}

output "opensearch_collection_endpoint" {
  description = "Endpoint of the OpenSearch Serverless collection"
  value       = var.knowledge_base != null && var.knowledge_base.enabled ? aws_opensearchserverless_collection.knowledge_base[0].collection_endpoint : null
}

output "data_source_id" {
  description = "ID of the knowledge base data source"
  value       = var.knowledge_base != null && var.knowledge_base.enabled ? aws_bedrockagent_data_source.s3[0].data_source_id : null
}

output "model_id" {
  description = "Bedrock model ID being used"
  value       = var.model_id
}

output "alarm_arns" {
  description = "Map of Bedrock alarm ARNs"
  value = {
    invocations = aws_cloudwatch_metric_alarm.bedrock_invocations.arn
    latency     = aws_cloudwatch_metric_alarm.bedrock_latency.arn
    throttles   = aws_cloudwatch_metric_alarm.bedrock_throttles.arn
  }
}
