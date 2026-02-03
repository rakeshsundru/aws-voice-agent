# =============================================================================
# S3 Module - Variables
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
  description = "Random suffix for globally unique bucket names"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "recordings_retention_days" {
  description = "Number of days to retain call recordings"
  type        = number
  default     = 90
}

variable "transcripts_retention_days" {
  description = "Number of days to retain transcripts"
  type        = number
  default     = 365
}

variable "artifacts_retention_days" {
  description = "Number of days to retain artifacts"
  type        = number
  default     = 365
}

variable "enable_versioning" {
  description = "Enable versioning on buckets"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Enable access logging on buckets"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Block all public access to buckets"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow buckets to be destroyed even if not empty"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
