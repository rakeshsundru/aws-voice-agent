# =============================================================================
# Lex Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bot_name" {
  description = "Name of the Lex bot"
  type        = string
  default     = null
}

variable "description" {
  description = "Bot description"
  type        = string
  default     = "Voice Agent Intent Recognition Bot"
}

variable "idle_session_ttl" {
  description = "Idle session TTL in seconds"
  type        = number
  default     = 300
}

variable "data_privacy" {
  description = "Data privacy configuration"
  type = object({
    child_directed = bool
  })
  default = {
    child_directed = false
  }
}

variable "lex_role_arn" {
  description = "IAM role ARN for Lex"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
