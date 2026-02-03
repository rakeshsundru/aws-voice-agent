# =============================================================================
# S3 Module - Storage Buckets
# =============================================================================

locals {
  bucket_configs = {
    recordings = {
      name           = "${var.name_prefix}-recordings-${var.random_suffix}"
      retention_days = var.recordings_retention_days
    }
    transcripts = {
      name           = "${var.name_prefix}-transcripts-${var.random_suffix}"
      retention_days = var.transcripts_retention_days
    }
    artifacts = {
      name           = "${var.name_prefix}-artifacts-${var.random_suffix}"
      retention_days = var.artifacts_retention_days
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Buckets
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "buckets" {
  for_each = local.bucket_configs

  bucket        = each.value.name
  force_destroy = var.force_destroy

  tags = merge(var.common_tags, {
    Name = each.value.name
    Type = each.key
  })
}

# -----------------------------------------------------------------------------
# Bucket Versioning
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "buckets" {
  for_each = local.bucket_configs

  bucket = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# -----------------------------------------------------------------------------
# Server-Side Encryption
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = local.bucket_configs

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# -----------------------------------------------------------------------------
# Public Access Block
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = local.bucket_configs

  bucket = aws_s3_bucket.buckets[each.key].id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

# -----------------------------------------------------------------------------
# Lifecycle Rules
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "buckets" {
  for_each = local.bucket_configs

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = each.value.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-to-ia"
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
  }

  depends_on = [aws_s3_bucket_versioning.buckets]
}

# -----------------------------------------------------------------------------
# Bucket Policy
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "buckets" {
  for_each = local.bucket_configs

  bucket = aws_s3_bucket.buckets[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Enforce HTTPS
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.buckets[each.key].arn,
          "${aws_s3_bucket.buckets[each.key].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      # Enforce encryption
      {
        Sid       = "EnforceEncryption"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.buckets]
}

# -----------------------------------------------------------------------------
# Access Logging Bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = "${var.name_prefix}-access-logs-${var.random_suffix}"
  force_destroy = var.force_destroy

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-access-logs-${var.random_suffix}"
    Type = "access-logs"
  })
}

resource "aws_s3_bucket_versioning" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.access_logs]
}

# -----------------------------------------------------------------------------
# Access Logging Configuration
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_logging" "buckets" {
  for_each = var.enable_access_logging ? local.bucket_configs : {}

  bucket = aws_s3_bucket.buckets[each.key].id

  target_bucket = aws_s3_bucket.access_logs[0].id
  target_prefix = "${each.key}/"
}

# -----------------------------------------------------------------------------
# CORS Configuration (for artifacts bucket - if needed for web access)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_cors_configuration" "artifacts" {
  bucket = aws_s3_bucket.buckets["artifacts"].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# -----------------------------------------------------------------------------
# Notification Configuration (for Lambda triggers)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_notification" "recordings" {
  bucket = aws_s3_bucket.buckets["recordings"].id

  # This can be configured later to trigger Lambda for processing
  # lambda_function {
  #   lambda_function_arn = var.processing_lambda_arn
  #   events              = ["s3:ObjectCreated:*"]
  #   filter_suffix       = ".wav"
  # }
}
