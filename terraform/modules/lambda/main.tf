# =============================================================================
# Lambda Module - Orchestration Functions
# =============================================================================

data "aws_region" "current" {}

locals {
  lambda_source_path = "${path.root}/../lambda"

  common_environment_variables = merge(
    {
      ENVIRONMENT              = var.environment
      LOG_LEVEL                = var.environment == "prod" ? "INFO" : "DEBUG"
      BEDROCK_MODEL_ID         = var.bedrock_config.model_id
      BEDROCK_MAX_TOKENS       = tostring(var.bedrock_config.max_tokens)
      BEDROCK_TEMPERATURE      = tostring(var.bedrock_config.temperature)
      BEDROCK_STREAMING        = tostring(var.bedrock_config.streaming_enabled)
      POLLY_VOICE_ID           = var.polly_config.voice_id
      POLLY_ENGINE             = var.polly_config.engine
      POLLY_LANGUAGE_CODE      = var.polly_config.language_code
      TRANSCRIBE_LANGUAGE_CODE = var.transcribe_config.language_code
      S3_BUCKET_RECORDINGS     = var.s3_bucket_recordings
      S3_BUCKET_TRANSCRIPTS    = var.s3_bucket_transcripts
      S3_BUCKET_ARTIFACTS      = var.s3_bucket_artifacts
      COMPANY_NAME             = var.agent_config.company_name
      MAX_CONVERSATION_TURNS   = tostring(var.agent_config.max_conversation_turns)
      NEPTUNE_ENABLED          = tostring(var.neptune_enabled)
      NEPTUNE_ENDPOINT         = var.neptune_endpoint
      NEPTUNE_PORT             = tostring(var.neptune_port)
    },
    var.environment_variables
  )
}

# -----------------------------------------------------------------------------
# Lambda Layer for Common Dependencies
# -----------------------------------------------------------------------------

resource "aws_lambda_layer_version" "dependencies" {
  filename            = "${local.lambda_source_path}/layers/dependencies.zip"
  layer_name          = "${var.name_prefix}-dependencies"
  description         = "Common Python dependencies for voice agent"
  compatible_runtimes = [var.runtime]

  # Only create if the zip file exists
  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Orchestrator Lambda Function
# -----------------------------------------------------------------------------

data "archive_file" "orchestrator" {
  type        = "zip"
  source_dir  = "${local.lambda_source_path}/orchestrator"
  output_path = "${local.lambda_source_path}/orchestrator.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

resource "aws_lambda_function" "orchestrator" {
  filename         = data.archive_file.orchestrator.output_path
  function_name    = "${var.name_prefix}-orchestrator"
  role             = var.lambda_role_arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.orchestrator.output_base64sha256
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = var.timeout

  reserved_concurrent_executions = var.reserved_concurrency > 0 ? var.reserved_concurrency : null

  environment {
    variables = local.common_environment_variables
  }

  vpc_config {
    subnet_ids         = var.vpc_config.subnet_ids
    security_group_ids = var.vpc_config.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  layers = concat(
    [aws_lambda_layer_version.dependencies.arn],
    var.layers
  )

  tags = merge(var.common_tags, {
    Name     = "${var.name_prefix}-orchestrator"
    Function = "orchestrator"
  })

  depends_on = [aws_cloudwatch_log_group.orchestrator]
}

# Orchestrator CloudWatch Log Group
resource "aws_cloudwatch_log_group" "orchestrator" {
  name              = "/aws/lambda/${var.name_prefix}-orchestrator"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

# Provisioned Concurrency (optional)
resource "aws_lambda_provisioned_concurrency_config" "orchestrator" {
  count = var.provisioned_concurrency > 0 ? 1 : 0

  function_name                     = aws_lambda_function.orchestrator.function_name
  provisioned_concurrent_executions = var.provisioned_concurrency
  qualifier                         = aws_lambda_function.orchestrator.version
}

# Lambda Alias for orchestrator
resource "aws_lambda_alias" "orchestrator" {
  name             = var.environment
  description      = "Alias for ${var.environment} environment"
  function_name    = aws_lambda_function.orchestrator.function_name
  function_version = aws_lambda_function.orchestrator.version
}

# -----------------------------------------------------------------------------
# Integration Lambda Function
# -----------------------------------------------------------------------------

data "archive_file" "integration" {
  type        = "zip"
  source_dir  = "${local.lambda_source_path}/integrations"
  output_path = "${local.lambda_source_path}/integrations.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

resource "aws_lambda_function" "integration" {
  filename         = data.archive_file.integration.output_path
  function_name    = "${var.name_prefix}-integration"
  role             = var.lambda_role_arn
  handler          = "api_connector.lambda_handler"
  source_code_hash = data.archive_file.integration.output_base64sha256
  runtime          = var.runtime
  memory_size      = 256
  timeout          = 30

  environment {
    variables = merge(local.common_environment_variables, {
      FUNCTION_TYPE = "integration"
    })
  }

  vpc_config {
    subnet_ids         = var.vpc_config.subnet_ids
    security_group_ids = var.vpc_config.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  layers = concat(
    [aws_lambda_layer_version.dependencies.arn],
    var.layers
  )

  tags = merge(var.common_tags, {
    Name     = "${var.name_prefix}-integration"
    Function = "integration"
  })

  depends_on = [aws_cloudwatch_log_group.integration]
}

# Integration CloudWatch Log Group
resource "aws_cloudwatch_log_group" "integration" {
  name              = "/aws/lambda/${var.name_prefix}-integration"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

# Lambda Alias for integration
resource "aws_lambda_alias" "integration" {
  name             = var.environment
  description      = "Alias for ${var.environment} environment"
  function_name    = aws_lambda_function.integration.function_name
  function_version = aws_lambda_function.integration.version
}

# -----------------------------------------------------------------------------
# Connect Lambda Permission
# -----------------------------------------------------------------------------

resource "aws_lambda_permission" "connect_orchestrator" {
  statement_id  = "AllowConnectInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "connect.amazonaws.com"
  # source_arn can be added if Connect instance ARN is known
}

resource "aws_lambda_permission" "connect_orchestrator_alias" {
  statement_id  = "AllowConnectInvokeAlias"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  qualifier     = aws_lambda_alias.orchestrator.name
  principal     = "connect.amazonaws.com"
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Lambda
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "orchestrator_errors" {
  alarm_name          = "${var.name_prefix}-orchestrator-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda orchestrator function errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.orchestrator.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "orchestrator_duration" {
  alarm_name          = "${var.name_prefix}-orchestrator-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.timeout * 1000 * 0.8  # 80% of timeout
  alarm_description   = "Lambda orchestrator function duration approaching timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.orchestrator.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "orchestrator_throttles" {
  alarm_name          = "${var.name_prefix}-orchestrator-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda orchestrator function is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.orchestrator.function_name
  }

  tags = var.common_tags
}
