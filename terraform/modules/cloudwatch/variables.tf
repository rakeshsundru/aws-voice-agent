# =============================================================================
# CloudWatch Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for log encryption"
  type        = string
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = true
}

variable "dashboard_enabled" {
  description = "Whether to create CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "alarms_config" {
  description = "Configuration for CloudWatch alarms"
  type = object({
    latency_threshold_ms         = optional(number, 2000)
    error_rate_threshold_percent = optional(number, 5)
    concurrent_calls_threshold   = optional(number, 100)
    lambda_errors_threshold      = optional(number, 10)
    lambda_duration_threshold_ms = optional(number, 10000)
    cost_alert_threshold_usd     = optional(number, 1000)
  })
  default = null
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
