# =============================================================================
# Secrets Module - AWS Secrets Manager Configuration
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Voice Agent Configuration Secret
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "voice_agent_config" {
  name        = "${var.name_prefix}/config"
  description = "Voice Agent configuration and API keys"
  kms_key_id  = var.kms_key_arn

  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "voice_agent_config" {
  secret_id = aws_secretsmanager_secret.voice_agent_config.id

  secret_string = jsonencode({
    environment = var.environment
    region      = data.aws_region.current.name

    # Bedrock Configuration
    bedrock = {
      model_id    = var.bedrock_model_id
      max_tokens  = var.bedrock_max_tokens
      temperature = var.bedrock_temperature
    }

    # Integration API Keys (placeholder - update after deployment)
    integrations = {
      crm_api_key     = var.crm_api_key
      crm_api_url     = var.crm_api_url
      webhook_secret  = var.webhook_secret
    }

    # Feature Flags
    features = {
      neptune_enabled = var.neptune_enabled
      lex_enabled     = var.lex_enabled
    }
  })
}

# -----------------------------------------------------------------------------
# Database Credentials Secret (for Neptune if enabled)
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "database_credentials" {
  count = var.neptune_enabled ? 1 : 0

  name        = "${var.name_prefix}/database"
  description = "Database connection credentials"
  kms_key_id  = var.kms_key_arn

  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  count = var.neptune_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.database_credentials[0].id

  secret_string = jsonencode({
    neptune_endpoint = var.neptune_endpoint
    neptune_port     = var.neptune_port
    use_iam_auth     = true
  })
}

# -----------------------------------------------------------------------------
# API Keys Secret (for external integrations)
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "api_keys" {
  name        = "${var.name_prefix}/api-keys"
  description = "External API keys and credentials"
  kms_key_id  = var.kms_key_arn

  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id

  secret_string = jsonencode({
    # Placeholder values - update via console or CLI after deployment
    external_api_key = "REPLACE_WITH_ACTUAL_KEY"

    # Add more API keys as needed
    services = {}
  })

  lifecycle {
    ignore_changes = [secret_string]  # Don't overwrite manual updates
  }
}

# -----------------------------------------------------------------------------
# Secret Rotation Configuration (optional)
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret_rotation" "api_keys" {
  count = var.enable_rotation ? 1 : 0

  secret_id           = aws_secretsmanager_secret.api_keys.id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}

# -----------------------------------------------------------------------------
# IAM Policy for Secrets Access
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid    = "GetSecretValue"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      aws_secretsmanager_secret.voice_agent_config.arn,
      aws_secretsmanager_secret.api_keys.arn,
    ]
  }

  dynamic "statement" {
    for_each = var.neptune_enabled ? [1] : []
    content {
      sid    = "GetDatabaseSecret"
      effect = "Allow"

      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]

      resources = [
        aws_secretsmanager_secret.database_credentials[0].arn
      ]
    }
  }

  statement {
    sid    = "DecryptSecrets"
    effect = "Allow"

    actions = [
      "kms:Decrypt"
    ]

    resources = [
      var.kms_key_arn
    ]
  }
}

resource "aws_iam_policy" "secrets_access" {
  name        = "${var.name_prefix}-secrets-access"
  description = "Policy for accessing voice agent secrets"
  policy      = data.aws_iam_policy_document.secrets_access.json

  tags = var.common_tags
}
