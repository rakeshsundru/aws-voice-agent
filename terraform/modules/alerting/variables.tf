# =============================================================================
# Alerting Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for SNS encryption"
  type        = string
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = null
}

variable "lambda_function_names" {
  description = "Map of Lambda function names to monitor"
  type        = map(string)
  default     = {}
}

variable "lambda_duration_threshold_ms" {
  description = "Lambda duration threshold in milliseconds"
  type        = number
  default     = 10000  # 10 seconds
}

variable "lambda_concurrency_threshold" {
  description = "Lambda concurrent execution threshold"
  type        = number
  default     = 50
}

variable "connect_instance_id" {
  description = "Connect instance ID for monitoring"
  type        = string
  default     = null
}

variable "dlq_arns" {
  description = "Map of DLQ names to queue ARNs for monitoring"
  type        = map(string)
  default     = {}
}

variable "enable_anomaly_detection" {
  description = "Enable CloudWatch anomaly detection"
  type        = bool
  default     = true
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD for cost alerts (0 to disable)"
  type        = number
  default     = 0
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
