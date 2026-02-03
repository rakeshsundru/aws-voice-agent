# =============================================================================
# Polly Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "voice_id" {
  description = "Polly voice ID"
  type        = string
  default     = "Joanna"
}

variable "engine" {
  description = "Polly engine (standard or neural)"
  type        = string
  default     = "neural"
}

variable "language_code" {
  description = "Language code"
  type        = string
  default     = "en-US"
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
