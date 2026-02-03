# =============================================================================
# Lambda Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "reserved_concurrency" {
  description = "Reserved concurrent executions (-1 for no limit)"
  type        = number
  default     = -1
}

variable "provisioned_concurrency" {
  description = "Provisioned concurrent executions (0 for none)"
  type        = number
  default     = 0
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "vpc_config" {
  description = "VPC configuration for Lambda"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "s3_bucket_recordings" {
  description = "S3 bucket name for recordings"
  type        = string
}

variable "s3_bucket_transcripts" {
  description = "S3 bucket name for transcripts"
  type        = string
}

variable "s3_bucket_artifacts" {
  description = "S3 bucket name for artifacts"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "bedrock_config" {
  description = "Bedrock configuration"
  type = object({
    model_id          = string
    max_tokens        = number
    temperature       = number
    streaming_enabled = bool
  })
}

variable "polly_config" {
  description = "Polly configuration"
  type = object({
    voice_id      = string
    engine        = string
    language_code = string
  })
}

variable "transcribe_config" {
  description = "Transcribe configuration"
  type = object({
    language_code = string
  })
}

variable "agent_config" {
  description = "Voice agent configuration"
  type = object({
    company_name           = string
    max_conversation_turns = number
  })
}

variable "neptune_enabled" {
  description = "Whether Neptune is enabled"
  type        = bool
  default     = false
}

variable "neptune_endpoint" {
  description = "Neptune cluster endpoint"
  type        = string
  default     = ""
}

variable "neptune_port" {
  description = "Neptune cluster port"
  type        = number
  default     = 8182
}

variable "environment_variables" {
  description = "Additional environment variables"
  type        = map(string)
  default     = {}
}

variable "layers" {
  description = "Additional Lambda layers"
  type        = list(string)
  default     = []
}

variable "enable_dlq" {
  description = "Enable Dead Letter Queues for Lambda functions"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
