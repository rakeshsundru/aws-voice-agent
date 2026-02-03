# =============================================================================
# Backup Module - AWS Backup and S3 Replication
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# AWS Backup Vault
# -----------------------------------------------------------------------------

resource "aws_backup_vault" "main" {
  name        = "${var.name_prefix}-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = var.common_tags
}

# Vault Lock for compliance (optional - prevents deletion)
resource "aws_backup_vault_lock_configuration" "main" {
  count = var.enable_vault_lock ? 1 : 0

  backup_vault_name   = aws_backup_vault.main.name
  min_retention_days  = var.min_retention_days
  max_retention_days  = var.max_retention_days
  changeable_for_days = var.changeable_for_days
}

# -----------------------------------------------------------------------------
# Backup Plan
# -----------------------------------------------------------------------------

resource "aws_backup_plan" "main" {
  name = "${var.name_prefix}-backup-plan"

  # Daily backup
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 * * ? *)"  # Daily at 5 AM UTC

    lifecycle {
      delete_after = var.daily_backup_retention_days
    }

    recovery_point_tags = merge(var.common_tags, {
      BackupType = "daily"
    })
  }

  # Weekly backup
  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * SUN *)"  # Every Sunday at 5 AM UTC

    lifecycle {
      delete_after       = var.weekly_backup_retention_days
      cold_storage_after = var.cold_storage_after_days
    }

    recovery_point_tags = merge(var.common_tags, {
      BackupType = "weekly"
    })
  }

  # Monthly backup
  rule {
    rule_name         = "monthly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 1 * ? *)"  # First day of month at 5 AM UTC

    lifecycle {
      delete_after       = var.monthly_backup_retention_days
      cold_storage_after = var.cold_storage_after_days
    }

    recovery_point_tags = merge(var.common_tags, {
      BackupType = "monthly"
    })
  }

  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "disabled"
    }
    resource_type = "EC2"
  }

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Backup Selection
# -----------------------------------------------------------------------------

resource "aws_backup_selection" "main" {
  name         = "${var.name_prefix}-backup-selection"
  plan_id      = aws_backup_plan.main.id
  iam_role_arn = aws_iam_role.backup.arn

  # Select resources by tags
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }

  # Also select specific resources
  resources = var.backup_resources
}

# -----------------------------------------------------------------------------
# Backup IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "backup" {
  name = "${var.name_prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Additional policy for S3 backups
resource "aws_iam_role_policy" "backup_s3" {
  name = "${var.name_prefix}-backup-s3-policy"
  role = aws_iam_role.backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketTagging",
          "s3:GetInventoryConfiguration",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl"
        ]
        Resource = "arn:aws:s3:::*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectAcl"
        ]
        Resource = "arn:aws:s3:::*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# S3 Backup Bucket (for cross-region or cross-account replication destination)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "backup" {
  count = var.create_backup_bucket ? 1 : 0

  bucket        = "${var.name_prefix}-backup-${var.random_suffix}"
  force_destroy = var.environment != "prod"

  tags = merge(var.common_tags, {
    Name   = "${var.name_prefix}-backup"
    Backup = "true"
  })
}

resource "aws_s3_bucket_versioning" "backup" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backup[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backup[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backup[0].id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# -----------------------------------------------------------------------------
# Backup Notifications
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "backup_notifications" {
  count = var.sns_topic_arn == null ? 1 : 0

  name              = "${var.name_prefix}-backup-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = var.common_tags
}

resource "aws_backup_vault_notifications" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  sns_topic_arn       = var.sns_topic_arn != null ? var.sns_topic_arn : aws_sns_topic.backup_notifications[0].arn
  backup_vault_events = ["BACKUP_JOB_FAILED", "RESTORE_JOB_COMPLETED", "BACKUP_JOB_COMPLETED"]
}

# SNS topic policy
resource "aws_sns_topic_policy" "backup" {
  count = var.sns_topic_arn == null ? 1 : 0

  arn = aws_sns_topic.backup_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowBackupPublish"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.backup_notifications[0].arn
    }]
  })
}
