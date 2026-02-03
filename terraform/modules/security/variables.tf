# =============================================================================
# Security Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "random_suffix" {
  description = "Random suffix for unique resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for flow logs"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  type        = string
  default     = null
}

variable "enable_sns_notifications" {
  description = "Enable SNS notifications for security findings"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub"
  type        = bool
  default     = true
}

variable "enable_aws_config" {
  description = "Enable AWS Config for compliance"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
