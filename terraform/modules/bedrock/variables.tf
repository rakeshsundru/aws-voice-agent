# =============================================================================
# Bedrock Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "model_id" {
  description = "Bedrock model ID"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "guardrails_enabled" {
  description = "Whether to enable guardrails"
  type        = bool
  default     = true
}

variable "knowledge_base" {
  description = "Knowledge base configuration"
  type = object({
    enabled           = bool
    s3_bucket_name    = optional(string)
    embedding_model   = optional(string, "amazon.titan-embed-text-v1")
    chunking_strategy = optional(string, "FIXED_SIZE")
    chunk_size        = optional(number, 512)
    chunk_overlap     = optional(number, 20)
  })
  default = null
}

variable "bedrock_role_arn" {
  description = "ARN of the Bedrock service role"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for knowledge base"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
