# =============================================================================
# IAM Module - Roles and Policies
# =============================================================================

# -----------------------------------------------------------------------------
# Lambda Execution Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Lambda Basic Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC Access Policy
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Custom Policy
resource "aws_iam_role_policy" "lambda_custom" {
  name = "${var.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Bedrock Access
      {
        Sid    = "BedrockAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetFoundationModel",
          "bedrock:ListFoundationModels",
          "bedrock:GetGuardrail",
          "bedrock:ApplyGuardrail",
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = "*"
      },
      # Polly Access
      {
        Sid    = "PollyAccess"
        Effect = "Allow"
        Action = [
          "polly:SynthesizeSpeech",
          "polly:DescribeVoices",
          "polly:GetLexicon",
          "polly:ListLexicons"
        ]
        Resource = "*"
      },
      # Transcribe Access
      {
        Sid    = "TranscribeAccess"
        Effect = "Allow"
        Action = [
          "transcribe:StartStreamTranscription",
          "transcribe:StartStreamTranscriptionWebSocket",
          "transcribe:GetVocabulary",
          "transcribe:GetVocabularyFilter"
        ]
        Resource = "*"
      },
      # S3 Access
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      },
      # KMS Access
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = values(var.kms_key_arns)
      },
      # CloudWatch Logs Access
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/${var.name_prefix}*",
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/${var.name_prefix}*:*"
        ]
      },
      # CloudWatch Metrics Access
      {
        Sid    = "CloudWatchMetricsAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "VoiceAgent"
          }
        }
      },
      # Secrets Manager Access
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.name_prefix}*"
      },
      # SSM Parameter Store Access
      {
        Sid    = "SSMAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.name_prefix}/*"
      },
      # Connect Access
      {
        Sid    = "ConnectAccess"
        Effect = "Allow"
        Action = [
          "connect:GetContactAttributes",
          "connect:UpdateContactAttributes",
          "connect:StartContactStreaming",
          "connect:StopContactStreaming"
        ]
        Resource = "*"
      }
    ]
  })
}

# Neptune Access Policy (Conditional)
resource "aws_iam_role_policy" "lambda_neptune" {
  count = var.neptune_enabled ? 1 : 0

  name = "${var.name_prefix}-lambda-neptune-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "NeptuneAccess"
        Effect = "Allow"
        Action = [
          "neptune-db:connect",
          "neptune-db:ReadDataViaQuery",
          "neptune-db:WriteDataViaQuery",
          "neptune-db:DeleteDataViaQuery"
        ]
        Resource = var.neptune_cluster_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Connect Service Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "connect" {
  name = "${var.name_prefix}-connect-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "connect.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "connect" {
  name = "${var.name_prefix}-connect-policy"
  role = aws_iam_role.connect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Access for recordings and transcripts
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketLocation"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      },
      # KMS Access
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = values(var.kms_key_arns)
      },
      # Lambda Invocation
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:${var.name_prefix}*"
      },
      # CloudWatch Logs
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/connect/*"
      },
      # Lex Access
      {
        Sid    = "LexAccess"
        Effect = "Allow"
        Action = [
          "lex:RecognizeText",
          "lex:RecognizeUtterance",
          "lex:StartConversation",
          "lex:PutSession",
          "lex:GetSession",
          "lex:DeleteSession"
        ]
        Resource = "arn:aws:lex:${var.aws_region}:${var.account_id}:bot-alias/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Bedrock Service Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "bedrock" {
  name = "${var.name_prefix}-bedrock-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${var.account_id}:*"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "bedrock" {
  name = "${var.name_prefix}-bedrock-policy"
  role = aws_iam_role.bedrock.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Access for Knowledge Base
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      },
      # KMS Access
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = values(var.kms_key_arns)
      },
      # OpenSearch Serverless (for Knowledge Base)
      {
        Sid    = "AOSSAccess"
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lex Service Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lex" {
  name = "${var.name_prefix}-lex-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lexv2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "lex" {
  name = "${var.name_prefix}-lex-policy"
  role = aws_iam_role.lex.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Polly Access
      {
        Sid    = "PollyAccess"
        Effect = "Allow"
        Action = [
          "polly:SynthesizeSpeech"
        ]
        Resource = "*"
      },
      # Comprehend Access (for sentiment analysis)
      {
        Sid    = "ComprehendAccess"
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Transcribe Service Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "transcribe" {
  name = "${var.name_prefix}-transcribe-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transcribe.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "transcribe" {
  name = "${var.name_prefix}-transcribe-policy"
  role = aws_iam_role.transcribe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Access
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      },
      # KMS Access
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = values(var.kms_key_arns)
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Events Role (for scheduled tasks)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "events" {
  name = "${var.name_prefix}-events-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "events" {
  name = "${var.name_prefix}-events-policy"
  role = aws_iam_role.events.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:${var.name_prefix}*"
      }
    ]
  })
}
