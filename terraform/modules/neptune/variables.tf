# =============================================================================
# Neptune Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_class" {
  description = "Neptune instance class"
  type        = string
  default     = "db.r5.large"
}

variable "cluster_size" {
  description = "Number of instances in the cluster"
  type        = number
  default     = 1
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "engine_version" {
  description = "Neptune engine version"
  type        = string
  default     = "1.2.1.0"
}

variable "port" {
  description = "Neptune port"
  type        = number
  default     = 8182
}

variable "iam_authentication" {
  description = "Enable IAM authentication"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Neptune"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Neptune"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
