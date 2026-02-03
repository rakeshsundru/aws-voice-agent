# =============================================================================
# KMS Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_encryption" {
  description = "Whether to enable encryption (create KMS keys)"
  type        = bool
  default     = true
}

variable "key_deletion_window" {
  description = "Number of days before a key is deleted after destruction"
  type        = number
  default     = 30
  validation {
    condition     = var.key_deletion_window >= 7 && var.key_deletion_window <= 30
    error_message = "Key deletion window must be between 7 and 30 days."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
