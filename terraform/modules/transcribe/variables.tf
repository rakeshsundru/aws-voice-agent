# =============================================================================
# Transcribe Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "language_code" {
  description = "Language code for transcription"
  type        = string
  default     = "en-US"
}

variable "vocabulary_name" {
  description = "Custom vocabulary name (optional)"
  type        = string
  default     = null
}

variable "vocabulary_filter_name" {
  description = "Vocabulary filter name (optional)"
  type        = string
  default     = null
}

variable "vocabulary_filter_method" {
  description = "Vocabulary filter method"
  type        = string
  default     = "mask"
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for vocabulary files"
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
