# =============================================================================
# IAM Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "kms_key_arns" {
  description = "Map of KMS key ARNs"
  type        = map(string)
  default     = {}
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs"
  type        = list(string)
  default     = []
}

variable "neptune_enabled" {
  description = "Whether Neptune is enabled"
  type        = bool
  default     = false
}

variable "neptune_cluster_arn" {
  description = "ARN of the Neptune cluster"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
