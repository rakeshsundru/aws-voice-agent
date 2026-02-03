# =============================================================================
# AWS Voice Agent - Terraform Variables
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "voice-agent"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------

variable "vpc_config" {
  description = "VPC configuration"
  type = object({
    create_new         = bool
    existing_vpc_id    = optional(string)
    cidr_block         = optional(string, "10.0.0.0/16")
    availability_zones = optional(list(string), [])
    private_subnets    = optional(list(string), ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"])
    public_subnets     = optional(list(string), ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"])
    enable_nat_gateway = optional(bool, true)
    single_nat_gateway = optional(bool, true)
  })
  default = {
    create_new = true
  }
}

# -----------------------------------------------------------------------------
# Amazon Connect Configuration
# -----------------------------------------------------------------------------

variable "connect_config" {
  description = "Amazon Connect configuration"
  type = object({
    instance_alias           = optional(string)
    existing_instance_id     = optional(string)
    identity_management_type = optional(string, "CONNECT_MANAGED")
    inbound_calls_enabled    = optional(bool, true)
    outbound_calls_enabled   = optional(bool, true)
    claim_phone_number       = optional(bool, true)
    phone_number_type        = optional(string, "DID")
    phone_number_country     = optional(string, "US")
    phone_number_prefix      = optional(string)
    contact_flow_logs        = optional(bool, true)
    hours_of_operation = optional(object({
      name      = string
      time_zone = string
      config = list(object({
        day        = string
        start_time = string
        end_time   = string
      }))
    }))
  })
}

# -----------------------------------------------------------------------------
# Amazon Bedrock Configuration
# -----------------------------------------------------------------------------

variable "bedrock_config" {
  description = "Amazon Bedrock configuration"
  type = object({
    model_id           = optional(string, "anthropic.claude-3-5-sonnet-20241022-v2:0")
    max_tokens         = optional(number, 2000)
    temperature        = optional(number, 0.7)
    top_p              = optional(number, 0.9)
    guardrails_enabled = optional(bool, true)
    streaming_enabled  = optional(bool, true)
    knowledge_base = optional(object({
      enabled          = bool
      s3_bucket_name   = optional(string)
      embedding_model  = optional(string, "amazon.titan-embed-text-v1")
      chunking_strategy = optional(string, "FIXED_SIZE")
      chunk_size       = optional(number, 512)
      chunk_overlap    = optional(number, 20)
    }))
  })
  default = {
    model_id           = "anthropic.claude-3-5-sonnet-20241022-v2:0"
    guardrails_enabled = true
  }
}

# -----------------------------------------------------------------------------
# Amazon Neptune Configuration (Phase 2)
# -----------------------------------------------------------------------------

variable "neptune_config" {
  description = "Amazon Neptune configuration"
  type = object({
    enabled                 = optional(bool, false)
    instance_class          = optional(string, "db.r5.large")
    cluster_size            = optional(number, 1)
    backup_retention_days   = optional(number, 7)
    preferred_backup_window = optional(string, "03:00-04:00")
    engine_version          = optional(string, "1.2.1.0")
    port                    = optional(number, 8182)
    iam_authentication      = optional(bool, true)
    deletion_protection     = optional(bool, false)
  })
  default = {
    enabled = false
  }
}

# -----------------------------------------------------------------------------
# Amazon Transcribe Configuration
# -----------------------------------------------------------------------------

variable "transcribe_config" {
  description = "Amazon Transcribe configuration"
  type = object({
    language_code               = optional(string, "en-US")
    media_sample_rate           = optional(number, 8000)
    media_encoding              = optional(string, "pcm")
    vocabulary_name             = optional(string)
    vocabulary_filter_name      = optional(string)
    vocabulary_filter_method    = optional(string, "mask")
    enable_partial_results      = optional(bool, true)
    pii_entity_types            = optional(list(string), ["ALL"])
    content_redaction_type      = optional(string, "PII")
    content_redaction_output    = optional(string, "redacted")
  })
  default = {}
}

# -----------------------------------------------------------------------------
# Amazon Lex Configuration
# -----------------------------------------------------------------------------

variable "lex_config" {
  description = "Amazon Lex V2 configuration"
  type = object({
    enabled             = optional(bool, false)
    bot_name            = optional(string)
    description         = optional(string, "Voice Agent Intent Recognition Bot")
    idle_session_ttl    = optional(number, 300)
    data_privacy = optional(object({
      child_directed = bool
    }), { child_directed = false })
  })
  default = {
    enabled = false
  }
}

# -----------------------------------------------------------------------------
# Amazon Polly Configuration
# -----------------------------------------------------------------------------

variable "polly_config" {
  description = "Amazon Polly configuration"
  type = object({
    voice_id      = optional(string, "Joanna")
    engine        = optional(string, "neural")
    language_code = optional(string, "en-US")
    output_format = optional(string, "pcm")
    sample_rate   = optional(string, "8000")
  })
  default = {}
}

# -----------------------------------------------------------------------------
# Lambda Configuration
# -----------------------------------------------------------------------------

variable "lambda_config" {
  description = "Lambda function configuration"
  type = object({
    runtime                = optional(string, "python3.11")
    memory_size            = optional(number, 512)
    timeout                = optional(number, 30)
    reserved_concurrency   = optional(number, -1)
    provisioned_concurrency = optional(number, 0)
    log_retention_days     = optional(number, 30)
    environment_variables  = optional(map(string), {})
    layers                 = optional(list(string), [])
  })
  default = {}
}

# -----------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------

variable "s3_config" {
  description = "S3 bucket configuration"
  type = object({
    recordings_retention_days  = optional(number, 90)
    transcripts_retention_days = optional(number, 365)
    artifacts_retention_days   = optional(number, 365)
    enable_versioning          = optional(bool, true)
    enable_access_logging      = optional(bool, true)
    block_public_access        = optional(bool, true)
    force_destroy              = optional(bool, false)
  })
  default = {}
}

# -----------------------------------------------------------------------------
# CloudWatch Configuration
# -----------------------------------------------------------------------------

variable "cloudwatch_config" {
  description = "CloudWatch monitoring configuration"
  type = object({
    log_retention_days          = optional(number, 30)
    enable_detailed_monitoring  = optional(bool, true)
    enable_contributor_insights = optional(bool, false)
    dashboard_enabled           = optional(bool, true)
    alarms = optional(object({
      latency_threshold_ms           = optional(number, 2000)
      error_rate_threshold_percent   = optional(number, 5)
      concurrent_calls_threshold     = optional(number, 100)
      lambda_errors_threshold        = optional(number, 10)
      lambda_duration_threshold_ms   = optional(number, 10000)
      cost_alert_threshold_usd       = optional(number, 1000)
    }))
    sns_topic_arn = optional(string)
  })
  default = {}
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "security_config" {
  description = "Security and compliance configuration"
  type = object({
    enable_encryption_at_rest    = optional(bool, true)
    enable_encryption_in_transit = optional(bool, true)
    kms_key_deletion_window      = optional(number, 30)
    enable_vpc_endpoints         = optional(bool, true)
    enable_cloudtrail            = optional(bool, true)
    enable_config                = optional(bool, false)
    allowed_ip_ranges            = optional(list(string), [])
    enable_waf                   = optional(bool, false)
  })
  default = {}
}

# -----------------------------------------------------------------------------
# Integration Configuration
# -----------------------------------------------------------------------------

variable "integration_config" {
  description = "External integration configuration"
  type = object({
    crm = optional(object({
      enabled      = bool
      endpoint_url = optional(string)
      api_key_ssm  = optional(string)
      timeout_ms   = optional(number, 5000)
    }))
    webhook = optional(object({
      enabled      = bool
      endpoint_url = optional(string)
      secret_ssm   = optional(string)
    }))
    sms = optional(object({
      enabled       = bool
      pinpoint_app  = optional(string)
      sender_id     = optional(string)
    }))
  })
  default = {}
}

# -----------------------------------------------------------------------------
# Agent Configuration
# -----------------------------------------------------------------------------

variable "agent_config" {
  description = "Voice agent behavior configuration"
  type = object({
    company_name              = optional(string, "Company")
    greeting_message          = optional(string, "Hello! How can I help you today?")
    fallback_message          = optional(string, "I'm sorry, I didn't quite understand that. Could you please rephrase?")
    transfer_message          = optional(string, "Let me transfer you to a specialist who can better assist you.")
    goodbye_message           = optional(string, "Thank you for calling. Goodbye!")
    max_conversation_turns    = optional(number, 50)
    silence_timeout_seconds   = optional(number, 10)
    max_call_duration_seconds = optional(number, 1800)
    enable_call_recording     = optional(bool, true)
    enable_transcription      = optional(bool, true)
  })
  default = {}
}
