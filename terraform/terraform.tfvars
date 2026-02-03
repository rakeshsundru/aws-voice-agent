# =============================================================================
# AWS Voice Agent - Development Deployment Configuration
# =============================================================================

project_name = "voice-agent"
environment  = "dev"
aws_region   = "us-east-1"

# VPC Configuration
vpc_config = {
  create_new         = true
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

# Amazon Connect Configuration - Using existing instance
connect_config = {
  instance_alias           = "insidata-voice-agent"  # Alias of existing instance
  existing_instance_id     = "86a0c9d5-97cd-4558-80f6-99389fdb2a34"  # Use existing Connect instance
  identity_management_type = "CONNECT_MANAGED"
  inbound_calls_enabled    = true
  outbound_calls_enabled   = true
  claim_phone_number       = false  # Claim manually in AWS Console (quota limit reached)
  phone_number_type        = "DID"
  phone_number_country     = "US"
  contact_flow_logs        = true
}

# Amazon Bedrock Configuration
bedrock_config = {
  model_id           = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  max_tokens         = 2000
  temperature        = 0.7
  guardrails_enabled = true
  streaming_enabled  = true
}

# Neptune disabled for initial deployment (Phase 1)
neptune_config = {
  enabled = false
}

# Lex V2 for intent recognition
lex_config = {
  enabled          = true
  bot_name         = "voice-agent-bot"
  description      = "Voice Agent Intent Recognition Bot"
  idle_session_ttl = 300
  data_privacy     = { child_directed = false }
}

# Lambda Configuration
lambda_config = {
  runtime              = "python3.11"
  memory_size          = 512
  timeout              = 30
  log_retention_days   = 30
}

# S3 Configuration
s3_config = {
  recordings_retention_days  = 90
  transcripts_retention_days = 365
  enable_versioning          = true
  enable_access_logging      = true
  block_public_access        = true
  force_destroy              = true  # For dev environment cleanup
}

# CloudWatch Configuration
cloudwatch_config = {
  log_retention_days         = 30
  enable_detailed_monitoring = true
  dashboard_enabled          = true
  alarms = {
    latency_threshold_ms         = 2000
    error_rate_threshold_percent = 5
    lambda_errors_threshold      = 10
  }
}

# Security Configuration
security_config = {
  enable_encryption_at_rest    = true
  enable_encryption_in_transit = true
  kms_key_deletion_window      = 7  # Shorter for dev
  enable_vpc_endpoints         = true
  enable_cloudtrail            = true  # Enabled for audit logging
}

# Transcribe Configuration
transcribe_config = {
  language_code            = "en-US"
  media_sample_rate        = 8000
  enable_partial_results   = true
}

# Polly Configuration
polly_config = {
  voice_id      = "Joanna"
  engine        = "neural"
  language_code = "en-US"
}

# Agent Configuration
agent_config = {
  company_name              = "Voice Agent Demo"
  greeting_message          = "Hello! Thank you for calling. How can I help you today?"
  fallback_message          = "I'm sorry, I didn't quite understand. Could you please rephrase that?"
  transfer_message          = "Let me transfer you to a specialist."
  goodbye_message           = "Thank you for calling. Have a great day!"
  max_conversation_turns    = 50
  silence_timeout_seconds   = 10
  max_call_duration_seconds = 1800
  enable_call_recording     = true
  enable_transcription      = true
}

common_tags = {
  Owner   = "rakesh@insidata.ai"
  Purpose = "Voice Agent Demo"
}
