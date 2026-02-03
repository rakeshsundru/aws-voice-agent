# =============================================================================
# Bedrock Module - LLM Configuration
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Bedrock Guardrail
# -----------------------------------------------------------------------------

resource "aws_bedrock_guardrail" "main" {
  count = var.guardrails_enabled ? 1 : 0

  name                      = "${var.name_prefix}-guardrail"
  description               = "Guardrail for voice agent - ${var.name_prefix}"
  blocked_input_messaging   = "I cannot process that request. Please rephrase your question."
  blocked_outputs_messaging = "I cannot provide that information. Let me help you with something else."

  # Content Policy - Filter harmful content
  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  # Topic Policy - Deny specific topics
  topic_policy_config {
    topics_config {
      name       = "financial_advice"
      definition = "Providing specific financial or investment advice including stock picks, portfolio allocation, or trading recommendations"
      type       = "DENY"
      examples   = [
        "What stocks should I buy?",
        "Should I invest in Bitcoin?",
        "How should I allocate my 401k?"
      ]
    }
    topics_config {
      name       = "medical_diagnosis"
      definition = "Diagnosing medical conditions, prescribing medications, or providing specific medical treatment advice"
      type       = "DENY"
      examples   = [
        "What medication should I take for my headache?",
        "Do I have diabetes based on my symptoms?",
        "Should I stop taking my prescribed medication?"
      ]
    }
    topics_config {
      name       = "legal_advice"
      definition = "Providing specific legal counsel, interpretation of laws, or legal strategy recommendations"
      type       = "DENY"
      examples   = [
        "Should I sue my employer?",
        "How do I get out of this contract?",
        "What are my legal rights in this situation?"
      ]
    }
  }

  # Sensitive Information Policy - Block PII
  sensitive_information_policy_config {
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "US_BANK_ACCOUNT_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "PIN"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "PASSWORD"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "DRIVER_ID"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "US_PASSPORT_NUMBER"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "ADDRESS"
      action = "ANONYMIZE"
    }
  }

  # Word Policy - Block profanity
  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }

  tags = var.common_tags
}

# Guardrail Version
resource "aws_bedrock_guardrail_version" "main" {
  count = var.guardrails_enabled ? 1 : 0

  guardrail_arn = aws_bedrock_guardrail.main[0].guardrail_arn
  description   = "Initial version for ${var.name_prefix}"
}

# -----------------------------------------------------------------------------
# Bedrock Knowledge Base (Optional)
# -----------------------------------------------------------------------------

# OpenSearch Serverless Collection for Knowledge Base
resource "aws_opensearchserverless_collection" "knowledge_base" {
  count = try(var.knowledge_base.enabled, false) ? 1 : 0

  name        = "${var.name_prefix}-kb"
  description = "Knowledge base collection for ${var.name_prefix}"
  type        = "VECTORSEARCH"

  tags = var.common_tags

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]
}

# OpenSearch Serverless Encryption Policy
resource "aws_opensearchserverless_security_policy" "encryption" {
  count = try(var.knowledge_base.enabled, false) ? 1 : 0

  name = "${var.name_prefix}-encryption"
  type = "encryption"

  policy = jsonencode({
    Rules = [
      {
        Resource     = ["collection/${var.name_prefix}-kb"]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

# OpenSearch Serverless Network Policy
resource "aws_opensearchserverless_security_policy" "network" {
  count = try(var.knowledge_base.enabled, false) ? 1 : 0

  name = "${var.name_prefix}-network"
  type = "network"

  policy = jsonencode([
    {
      Rules = [
        {
          Resource     = ["collection/${var.name_prefix}-kb"]
          ResourceType = "collection"
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# OpenSearch Serverless Access Policy
resource "aws_opensearchserverless_access_policy" "knowledge_base" {
  count = try(var.knowledge_base.enabled, false) ? 1 : 0

  name = "${var.name_prefix}-access"
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          Resource     = ["collection/${var.name_prefix}-kb"]
          ResourceType = "collection"
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          Resource     = ["index/${var.name_prefix}-kb/*"]
          ResourceType = "index"
          Permission = [
            "aoss:CreateIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ]
      Principal = [
        data.aws_caller_identity.current.arn,
        var.bedrock_role_arn
      ]
    }
  ])
}

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "main" {
  count = try(var.knowledge_base.enabled, false) ? 1 : 0

  name        = "${var.name_prefix}-knowledge-base"
  description = "Knowledge base for voice agent - ${var.name_prefix}"
  role_arn    = var.bedrock_role_arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.knowledge_base.embedding_model}"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.knowledge_base[0].arn
      vector_index_name = "${var.name_prefix}-index"
      field_mapping {
        vector_field   = "embedding"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
  }

  tags = var.common_tags
}

# Knowledge Base Data Source (S3)
resource "aws_bedrockagent_data_source" "s3" {
  count = try(var.knowledge_base.enabled, false) ? 1 : 0

  knowledge_base_id = aws_bedrockagent_knowledge_base.main[0].id
  name              = "${var.name_prefix}-s3-source"
  description       = "S3 data source for knowledge base"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.s3_bucket_arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = var.knowledge_base.chunking_strategy
      fixed_size_chunking_configuration {
        max_tokens         = var.knowledge_base.chunk_size
        overlap_percentage = var.knowledge_base.chunk_overlap
      }
    }
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Bedrock
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "bedrock_invocations" {
  alarm_name          = "${var.name_prefix}-bedrock-invocations"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "Invocations"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "No Bedrock invocations detected - possible issue"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ModelId = var.model_id
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "bedrock_latency" {
  alarm_name          = "${var.name_prefix}-bedrock-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "InvocationLatency"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Average"
  threshold           = 5000  # 5 seconds
  alarm_description   = "High Bedrock invocation latency"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ModelId = var.model_id
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "bedrock_throttles" {
  alarm_name          = "${var.name_prefix}-bedrock-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "InvocationThrottles"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Bedrock is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ModelId = var.model_id
  }

  tags = var.common_tags
}
