# =============================================================================
# AWS Voice Agent - Main Terraform Configuration
# =============================================================================

locals {
  # Resource naming
  name_prefix = var.resource_prefix != "" ? var.resource_prefix : "${var.project_name}-${var.environment}"

  # Common tags
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )

  # Availability zones
  azs = length(var.vpc_config.availability_zones) > 0 ? var.vpc_config.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------------------------------------------------------
# Random suffix for unique resource names
# -----------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 4
}

# -----------------------------------------------------------------------------
# KMS Module - Encryption keys
# -----------------------------------------------------------------------------

module "kms" {
  source = "./modules/kms"

  name_prefix             = local.name_prefix
  environment             = var.environment
  enable_encryption       = var.security_config.enable_encryption_at_rest
  key_deletion_window     = var.security_config.kms_key_deletion_window
  common_tags             = local.common_tags
}

# -----------------------------------------------------------------------------
# VPC Module - Network infrastructure
# -----------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  create_vpc         = var.vpc_config.create_new
  existing_vpc_id    = var.vpc_config.existing_vpc_id
  name_prefix        = local.name_prefix
  environment        = var.environment
  cidr_block         = var.vpc_config.cidr_block
  availability_zones = local.azs
  private_subnets    = var.vpc_config.private_subnets
  public_subnets     = var.vpc_config.public_subnets
  enable_nat_gateway = var.vpc_config.enable_nat_gateway
  single_nat_gateway = var.vpc_config.single_nat_gateway
  enable_vpc_endpoints = var.security_config.enable_vpc_endpoints
  common_tags        = local.common_tags
}

# -----------------------------------------------------------------------------
# IAM Module - Roles and policies
# -----------------------------------------------------------------------------

module "iam" {
  source = "./modules/iam"

  name_prefix         = local.name_prefix
  environment         = var.environment
  aws_region          = var.aws_region
  account_id          = data.aws_caller_identity.current.account_id
  kms_key_arns        = module.kms.key_arns
  s3_bucket_arns      = values(module.s3.bucket_arns)
  neptune_enabled     = var.neptune_config.enabled
  neptune_cluster_arn = var.neptune_config.enabled ? module.neptune[0].cluster_arn : ""
  common_tags         = local.common_tags
}

# -----------------------------------------------------------------------------
# S3 Module - Storage buckets
# -----------------------------------------------------------------------------

module "s3" {
  source = "./modules/s3"

  name_prefix                = local.name_prefix
  environment                = var.environment
  random_suffix              = random_id.suffix.hex
  kms_key_arn                = module.kms.key_arns["s3"]
  recordings_retention_days  = var.s3_config.recordings_retention_days
  transcripts_retention_days = var.s3_config.transcripts_retention_days
  artifacts_retention_days   = var.s3_config.artifacts_retention_days
  enable_versioning          = var.s3_config.enable_versioning
  enable_access_logging      = var.s3_config.enable_access_logging
  block_public_access        = var.s3_config.block_public_access
  force_destroy              = var.s3_config.force_destroy
  common_tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudWatch Module - Monitoring and logging
# -----------------------------------------------------------------------------

module "cloudwatch" {
  source = "./modules/cloudwatch"

  name_prefix                 = local.name_prefix
  environment                 = var.environment
  log_retention_days          = var.cloudwatch_config.log_retention_days
  kms_key_arn                 = module.kms.key_arns["cloudwatch"]
  enable_detailed_monitoring  = var.cloudwatch_config.enable_detailed_monitoring
  dashboard_enabled           = var.cloudwatch_config.dashboard_enabled
  alarms_config               = var.cloudwatch_config.alarms
  sns_topic_arn               = var.cloudwatch_config.sns_topic_arn
  common_tags                 = local.common_tags
}

# -----------------------------------------------------------------------------
# Lambda Module - Orchestration functions
# -----------------------------------------------------------------------------

module "lambda" {
  source = "./modules/lambda"

  name_prefix              = local.name_prefix
  environment              = var.environment
  runtime                  = var.lambda_config.runtime
  memory_size              = var.lambda_config.memory_size
  timeout                  = var.lambda_config.timeout
  reserved_concurrency     = var.lambda_config.reserved_concurrency
  provisioned_concurrency  = var.lambda_config.provisioned_concurrency
  log_retention_days       = var.lambda_config.log_retention_days
  lambda_role_arn          = module.iam.lambda_role_arn
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.lambda_security_group_id]
  }
  kms_key_arn              = module.kms.key_arns["lambda"]
  s3_bucket_recordings     = module.s3.bucket_names["recordings"]
  s3_bucket_transcripts    = module.s3.bucket_names["transcripts"]
  s3_bucket_artifacts      = module.s3.bucket_names["artifacts"]
  log_group_name           = module.cloudwatch.lambda_log_group_name
  bedrock_config           = var.bedrock_config
  polly_config             = var.polly_config
  transcribe_config        = var.transcribe_config
  agent_config             = var.agent_config
  neptune_enabled          = var.neptune_config.enabled
  neptune_endpoint         = var.neptune_config.enabled ? module.neptune[0].cluster_endpoint : ""
  neptune_port             = var.neptune_config.port
  environment_variables    = var.lambda_config.environment_variables
  layers                   = var.lambda_config.layers
  common_tags              = local.common_tags

  depends_on = [module.iam, module.vpc, module.s3, module.cloudwatch]
}

# -----------------------------------------------------------------------------
# Connect Module - Telephony
# -----------------------------------------------------------------------------

module "connect" {
  source = "./modules/connect"

  name_prefix              = local.name_prefix
  environment              = var.environment
  instance_alias           = var.connect_config.instance_alias != null ? var.connect_config.instance_alias : "voice-agent-${var.environment}"
  existing_instance_id     = var.connect_config.existing_instance_id
  identity_management_type = var.connect_config.identity_management_type
  inbound_calls_enabled    = var.connect_config.inbound_calls_enabled
  outbound_calls_enabled   = var.connect_config.outbound_calls_enabled
  claim_phone_number       = var.connect_config.claim_phone_number
  phone_number_type        = var.connect_config.phone_number_type
  phone_number_country     = var.connect_config.phone_number_country
  phone_number_prefix      = var.connect_config.phone_number_prefix
  contact_flow_logs        = var.connect_config.contact_flow_logs
  hours_of_operation       = var.connect_config.hours_of_operation
  lambda_function_arn      = module.lambda.orchestrator_function_arn
  s3_bucket_recordings     = module.s3.bucket_names["recordings"]
  s3_bucket_transcripts    = module.s3.bucket_names["transcripts"]
  kms_key_arn              = module.kms.key_arns["connect"]
  cloudwatch_log_group     = module.cloudwatch.connect_log_group_name
  common_tags              = local.common_tags

  depends_on = [module.lambda, module.s3, module.kms]
}

# -----------------------------------------------------------------------------
# Bedrock Module - LLM configuration
# -----------------------------------------------------------------------------

module "bedrock" {
  source = "./modules/bedrock"

  name_prefix        = local.name_prefix
  environment        = var.environment
  model_id           = var.bedrock_config.model_id
  guardrails_enabled = var.bedrock_config.guardrails_enabled
  knowledge_base     = var.bedrock_config.knowledge_base
  bedrock_role_arn   = module.iam.bedrock_role_arn
  s3_bucket_arn      = module.s3.bucket_arns["artifacts"]
  kms_key_arn        = module.kms.key_arns["bedrock"]
  common_tags        = local.common_tags

  depends_on = [module.iam, module.s3, module.kms]
}

# -----------------------------------------------------------------------------
# Transcribe Module - Speech-to-text
# -----------------------------------------------------------------------------

module "transcribe" {
  source = "./modules/transcribe"

  name_prefix              = local.name_prefix
  environment              = var.environment
  language_code            = var.transcribe_config.language_code
  vocabulary_name          = var.transcribe_config.vocabulary_name
  vocabulary_filter_name   = var.transcribe_config.vocabulary_filter_name
  vocabulary_filter_method = var.transcribe_config.vocabulary_filter_method
  s3_bucket_arn            = module.s3.bucket_arns["transcripts"]
  kms_key_arn              = module.kms.key_arns["transcribe"]
  common_tags              = local.common_tags
}

# -----------------------------------------------------------------------------
# Lex Module - Intent recognition (Optional)
# -----------------------------------------------------------------------------

module "lex" {
  source = "./modules/lex"
  count  = var.lex_config.enabled ? 1 : 0

  name_prefix          = local.name_prefix
  environment          = var.environment
  bot_name             = var.lex_config.bot_name
  description          = var.lex_config.description
  idle_session_ttl     = var.lex_config.idle_session_ttl
  data_privacy         = var.lex_config.data_privacy
  lex_role_arn         = module.iam.lex_role_arn
  common_tags          = local.common_tags
}

# -----------------------------------------------------------------------------
# Polly Module - Text-to-speech
# -----------------------------------------------------------------------------

module "polly" {
  source = "./modules/polly"

  name_prefix   = local.name_prefix
  environment   = var.environment
  voice_id      = var.polly_config.voice_id
  engine        = var.polly_config.engine
  language_code = var.polly_config.language_code
  common_tags   = local.common_tags
}

# -----------------------------------------------------------------------------
# Neptune Module - Graph database (Phase 2)
# -----------------------------------------------------------------------------

module "neptune" {
  source = "./modules/neptune"
  count  = var.neptune_config.enabled ? 1 : 0

  name_prefix             = local.name_prefix
  environment             = var.environment
  instance_class          = var.neptune_config.instance_class
  cluster_size            = var.neptune_config.cluster_size
  backup_retention_days   = var.neptune_config.backup_retention_days
  preferred_backup_window = var.neptune_config.preferred_backup_window
  engine_version          = var.neptune_config.engine_version
  port                    = var.neptune_config.port
  iam_authentication      = var.neptune_config.iam_authentication
  deletion_protection     = var.neptune_config.deletion_protection
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  security_group_id       = module.vpc.neptune_security_group_id
  kms_key_arn             = module.kms.key_arns["neptune"]
  common_tags             = local.common_tags

  depends_on = [module.vpc, module.kms]
}

# -----------------------------------------------------------------------------
# CloudTrail Module - Audit logging (Optional)
# -----------------------------------------------------------------------------

module "cloudtrail" {
  source = "./modules/cloudtrail"
  count  = var.security_config.enable_cloudtrail ? 1 : 0

  name_prefix        = local.name_prefix
  environment        = var.environment
  random_suffix      = random_id.suffix.hex
  log_retention_days = var.cloudwatch_config.log_retention_days
  multi_region       = false
  force_destroy      = var.s3_config.force_destroy
  common_tags        = local.common_tags
}
