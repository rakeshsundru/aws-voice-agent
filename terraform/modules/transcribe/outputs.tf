# =============================================================================
# Transcribe Module - Outputs
# =============================================================================

output "vocabulary_name" {
  description = "Name of the custom vocabulary"
  value       = var.vocabulary_name != null ? aws_transcribe_vocabulary.custom[0].vocabulary_name : null
}

output "vocabulary_filter_name" {
  description = "Name of the vocabulary filter"
  value       = var.vocabulary_filter_name != null ? aws_transcribe_vocabulary_filter.profanity[0].vocabulary_filter_name : null
}
