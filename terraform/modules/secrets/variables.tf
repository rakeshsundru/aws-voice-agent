# =============================================================================
# Secrets Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

# Bedrock Configuration
variable "bedrock_model_id" {
  description = "Bedrock model ID"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "bedrock_max_tokens" {
  description = "Bedrock max tokens"
  type        = number
  default     = 1024
}

variable "bedrock_temperature" {
  description = "Bedrock temperature"
  type        = number
  default     = 0.7
}

# Integration Configuration
variable "crm_api_key" {
  description = "CRM API key (placeholder)"
  type        = string
  default     = "REPLACE_ME"
  sensitive   = true
}

variable "crm_api_url" {
  description = "CRM API URL"
  type        = string
  default     = ""
}

variable "webhook_secret" {
  description = "Webhook signing secret"
  type        = string
  default     = "REPLACE_ME"
  sensitive   = true
}

# Feature Flags
variable "neptune_enabled" {
  description = "Whether Neptune is enabled"
  type        = bool
  default     = false
}

variable "neptune_endpoint" {
  description = "Neptune endpoint"
  type        = string
  default     = ""
}

variable "neptune_port" {
  description = "Neptune port"
  type        = number
  default     = 8182
}

variable "lex_enabled" {
  description = "Whether Lex is enabled"
  type        = bool
  default     = false
}

# Rotation Configuration
variable "enable_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "ARN of Lambda function for rotation"
  type        = string
  default     = null
}

variable "rotation_days" {
  description = "Days between automatic rotations"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
