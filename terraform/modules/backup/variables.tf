# =============================================================================
# Backup Module - Variables
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
  description = "Random suffix for unique bucket names"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = null
}

variable "create_sns_topic" {
  description = "Create a dedicated SNS topic for backup notifications"
  type        = bool
  default     = true
}

variable "enable_notifications" {
  description = "Enable backup vault notifications (either via created or provided SNS topic)"
  type        = bool
  default     = true
}

# Retention Configuration
variable "daily_backup_retention_days" {
  description = "Days to retain daily backups"
  type        = number
  default     = 7
}

variable "weekly_backup_retention_days" {
  description = "Days to retain weekly backups"
  type        = number
  default     = 35
}

variable "monthly_backup_retention_days" {
  description = "Days to retain monthly backups"
  type        = number
  default     = 365
}

variable "cold_storage_after_days" {
  description = "Days before moving to cold storage"
  type        = number
  default     = 90
}

# Vault Lock Configuration
variable "enable_vault_lock" {
  description = "Enable vault lock for compliance"
  type        = bool
  default     = false
}

variable "min_retention_days" {
  description = "Minimum retention days for vault lock"
  type        = number
  default     = 7
}

variable "max_retention_days" {
  description = "Maximum retention days for vault lock"
  type        = number
  default     = 365
}

variable "changeable_for_days" {
  description = "Days the vault lock can be changed"
  type        = number
  default     = 3
}

# Resources to backup
variable "backup_resources" {
  description = "List of resource ARNs to backup"
  type        = list(string)
  default     = []
}

# S3 Backup Bucket
variable "create_backup_bucket" {
  description = "Create a dedicated backup bucket"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
