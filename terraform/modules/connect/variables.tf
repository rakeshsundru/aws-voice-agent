# =============================================================================
# Connect Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_alias" {
  description = "Alias for the Connect instance"
  type        = string
}

variable "existing_instance_id" {
  description = "ID of existing Connect instance to use (if not creating a new one)"
  type        = string
  default     = null
}

variable "identity_management_type" {
  description = "Identity management type (CONNECT_MANAGED, SAML, or EXISTING_DIRECTORY)"
  type        = string
  default     = "CONNECT_MANAGED"
  validation {
    condition     = contains(["CONNECT_MANAGED", "SAML", "EXISTING_DIRECTORY"], var.identity_management_type)
    error_message = "Identity management type must be CONNECT_MANAGED, SAML, or EXISTING_DIRECTORY."
  }
}

variable "inbound_calls_enabled" {
  description = "Whether inbound calls are enabled"
  type        = bool
  default     = true
}

variable "outbound_calls_enabled" {
  description = "Whether outbound calls are enabled"
  type        = bool
  default     = true
}

variable "claim_phone_number" {
  description = "Whether to claim a phone number"
  type        = bool
  default     = true
}

variable "phone_number_type" {
  description = "Type of phone number (DID or TOLL_FREE)"
  type        = string
  default     = "DID"
  validation {
    condition     = contains(["DID", "TOLL_FREE"], var.phone_number_type)
    error_message = "Phone number type must be DID or TOLL_FREE."
  }
}

variable "phone_number_country" {
  description = "Country code for the phone number"
  type        = string
  default     = "US"
}

variable "phone_number_prefix" {
  description = "Prefix for the phone number (optional)"
  type        = string
  default     = null
}

variable "contact_flow_logs" {
  description = "Enable contact flow logs"
  type        = bool
  default     = true
}

variable "hours_of_operation" {
  description = "Hours of operation configuration"
  type = object({
    name      = string
    time_zone = string
    config = list(object({
      day        = string
      start_time = string
      end_time   = string
    }))
  })
  default = null
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to invoke"
  type        = string
}

variable "s3_bucket_recordings" {
  description = "S3 bucket name for call recordings"
  type        = string
}

variable "s3_bucket_transcripts" {
  description = "S3 bucket name for transcripts"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "cloudwatch_log_group" {
  description = "CloudWatch log group name for Connect logs"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
