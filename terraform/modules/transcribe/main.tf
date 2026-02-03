# =============================================================================
# Transcribe Module - Speech-to-Text Configuration
# =============================================================================

# Note: Amazon Transcribe streaming is configured at runtime via the Lambda function.
# This module manages any custom vocabularies or vocabulary filters.

# -----------------------------------------------------------------------------
# Custom Vocabulary (Optional)
# -----------------------------------------------------------------------------

resource "aws_transcribe_vocabulary" "custom" {
  count = var.vocabulary_name != null ? 1 : 0

  vocabulary_name     = var.vocabulary_name
  language_code       = var.language_code
  vocabulary_file_uri = "s3://${var.s3_bucket_arn}/vocabularies/${var.vocabulary_name}.txt"

  tags = merge(var.common_tags, {
    Name = var.vocabulary_name
  })
}

# -----------------------------------------------------------------------------
# Vocabulary Filter (Optional)
# -----------------------------------------------------------------------------

resource "aws_transcribe_vocabulary_filter" "profanity" {
  count = var.vocabulary_filter_name != null ? 1 : 0

  vocabulary_filter_name     = var.vocabulary_filter_name
  language_code              = var.language_code
  vocabulary_filter_file_uri = "s3://${var.s3_bucket_arn}/filters/${var.vocabulary_filter_name}.txt"

  tags = merge(var.common_tags, {
    Name = var.vocabulary_filter_name
  })
}
