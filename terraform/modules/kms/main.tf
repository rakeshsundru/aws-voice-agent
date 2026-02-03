# =============================================================================
# KMS Module - Encryption Keys
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  key_types = var.enable_encryption ? ["s3", "lambda", "cloudwatch", "connect", "bedrock", "neptune", "transcribe"] : []
}

# -----------------------------------------------------------------------------
# KMS Keys for each service
# -----------------------------------------------------------------------------

resource "aws_kms_key" "keys" {
  for_each = toset(local.key_types)

  description              = "KMS key for ${each.key} encryption - ${var.name_prefix}"
  deletion_window_in_days  = var.key_deletion_window
  enable_key_rotation      = true
  is_enabled               = true
  multi_region             = false

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name_prefix}-${each.key}-key-policy"
    Statement = [
      # Allow root account full access
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Allow service principals to use the key
      {
        Sid    = "AllowServicePrincipalUse"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals[each.key]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      # Allow CloudWatch Logs to use the key
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.name_prefix}-${each.key}-key"
    Service = each.key
  })
}

# Service principals for each key type
locals {
  service_principals = {
    s3         = "s3.amazonaws.com"
    lambda     = "lambda.amazonaws.com"
    cloudwatch = "logs.amazonaws.com"
    connect    = "connect.amazonaws.com"
    bedrock    = "bedrock.amazonaws.com"
    neptune    = "rds.amazonaws.com"
    transcribe = "transcribe.amazonaws.com"
  }
}

# -----------------------------------------------------------------------------
# KMS Key Aliases
# -----------------------------------------------------------------------------

resource "aws_kms_alias" "keys" {
  for_each = toset(local.key_types)

  name          = "alias/${var.name_prefix}-${each.key}"
  target_key_id = aws_kms_key.keys[each.key].key_id
}

# -----------------------------------------------------------------------------
# Default key for general use (when specific key not needed)
# -----------------------------------------------------------------------------

resource "aws_kms_key" "default" {
  count = var.enable_encryption ? 1 : 0

  description              = "Default KMS key for ${var.name_prefix}"
  deletion_window_in_days  = var.key_deletion_window
  enable_key_rotation      = true
  is_enabled               = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name_prefix}-default-key-policy"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-default-key"
  })
}

resource "aws_kms_alias" "default" {
  count = var.enable_encryption ? 1 : 0

  name          = "alias/${var.name_prefix}-default"
  target_key_id = aws_kms_key.default[0].key_id
}
