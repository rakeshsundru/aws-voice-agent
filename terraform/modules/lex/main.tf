# =============================================================================
# Lex Module - Intent Recognition (Optional)
# =============================================================================

# -----------------------------------------------------------------------------
# Lex Bot
# -----------------------------------------------------------------------------

resource "aws_lexv2models_bot" "main" {
  name        = var.bot_name != null ? var.bot_name : "${var.name_prefix}-bot"
  description = var.description
  role_arn    = var.lex_role_arn

  data_privacy {
    child_directed = var.data_privacy.child_directed
  }

  idle_session_ttl_in_seconds = var.idle_session_ttl

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Bot Locale
# -----------------------------------------------------------------------------

resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id                           = aws_lexv2models_bot.main.id
  bot_version                      = "DRAFT"
  locale_id                        = "en_US"
  n_lu_intent_confidence_threshold = 0.7

  voice_settings {
    voice_id = "Joanna"
    engine   = "neural"
  }
}

# -----------------------------------------------------------------------------
# Bot Version
# -----------------------------------------------------------------------------

resource "aws_lexv2models_bot_version" "main" {
  bot_id = aws_lexv2models_bot.main.id

  locale_specification = {
    "en_US" = {
      source_bot_version = "DRAFT"
    }
  }
}
