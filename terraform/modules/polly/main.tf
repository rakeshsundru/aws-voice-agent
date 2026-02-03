# =============================================================================
# Polly Module - Text-to-Speech Configuration
# =============================================================================

# Note: Amazon Polly is used via API calls from Lambda.
# This module primarily stores configuration and can manage lexicons.

locals {
  polly_config = {
    voice_id      = var.voice_id
    engine        = var.engine
    language_code = var.language_code
    output_format = "pcm"
    sample_rate   = "8000"
  }
}

# Store Polly configuration in SSM for Lambda to retrieve
resource "aws_ssm_parameter" "polly_config" {
  name        = "/${var.name_prefix}/polly/config"
  description = "Polly configuration for voice agent"
  type        = "String"
  value       = jsonencode(local.polly_config)

  tags = var.common_tags
}

# Custom lexicon for pronunciation (optional)
# resource "aws_polly_lexicon" "custom" {
#   name    = "${var.name_prefix}-lexicon"
#   content = file("${path.module}/lexicon.xml")
# }
