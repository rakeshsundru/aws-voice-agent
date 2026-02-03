# =============================================================================
# Alerting Module - SNS Topics, Enhanced Alarms, Anomaly Detection
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# SNS Topics for Alerts
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "critical" {
  name              = "${var.name_prefix}-critical-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    AlertLevel = "critical"
  })
}

resource "aws_sns_topic" "warning" {
  name              = "${var.name_prefix}-warning-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    AlertLevel = "warning"
  })
}

resource "aws_sns_topic" "info" {
  name              = "${var.name_prefix}-info-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    AlertLevel = "info"
  })
}

# SNS Topic Policy for CloudWatch
resource "aws_sns_topic_policy" "critical" {
  arn = aws_sns_topic.critical.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.critical.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:*"
          }
        }
      },
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.critical.arn
      }
    ]
  })
}

resource "aws_sns_topic_policy" "warning" {
  arn = aws_sns_topic.warning.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudWatchAlarms"
      Effect = "Allow"
      Principal = {
        Service = "cloudwatch.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.warning.arn
    }]
  })
}

# Email Subscriptions
resource "aws_sns_topic_subscription" "critical_email" {
  count = var.alert_email != null ? 1 : 0

  topic_arn = aws_sns_topic.critical.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "warning_email" {
  count = var.alert_email != null ? 1 : 0

  topic_arn = aws_sns_topic.warning.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# -----------------------------------------------------------------------------
# Enhanced Lambda Alarms
# -----------------------------------------------------------------------------

# Lambda Errors (Critical)
resource "aws_cloudwatch_metric_alarm" "lambda_errors_critical" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.name_prefix}-${each.key}-errors-critical"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Critical: Lambda ${each.key} error count exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.critical.arn]
  ok_actions    = [aws_sns_topic.info.arn]

  tags = var.common_tags
}

# Lambda Duration (Warning)
resource "aws_cloudwatch_metric_alarm" "lambda_duration_warning" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.name_prefix}-${each.key}-duration-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p95"
  threshold           = var.lambda_duration_threshold_ms
  alarm_description   = "Warning: Lambda ${each.key} p95 duration exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.warning.arn]
  ok_actions    = [aws_sns_topic.info.arn]

  tags = var.common_tags
}

# Lambda Throttles (Critical)
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.name_prefix}-${each.key}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Critical: Lambda ${each.key} is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.critical.arn]
  ok_actions    = [aws_sns_topic.info.arn]

  tags = var.common_tags
}

# Lambda Concurrent Executions (Warning)
resource "aws_cloudwatch_metric_alarm" "lambda_concurrency" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.name_prefix}-${each.key}-high-concurrency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.lambda_concurrency_threshold
  alarm_description   = "Warning: Lambda ${each.key} concurrent executions high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.warning.arn]
  ok_actions    = [aws_sns_topic.info.arn]

  tags = var.common_tags
}

# Lambda Dead Letter Errors (Critical)
resource "aws_cloudwatch_metric_alarm" "lambda_dlq_errors" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.name_prefix}-${each.key}-dlq-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DeadLetterErrors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Critical: Lambda ${each.key} failed to send to DLQ"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.critical.arn]

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Bedrock Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "bedrock_throttles" {
  alarm_name          = "${var.name_prefix}-bedrock-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ThrottledCount"
  namespace           = "AWS/Bedrock"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Warning: Bedrock API throttling detected"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.warning.arn]
  ok_actions    = [aws_sns_topic.info.arn]

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "bedrock_latency" {
  alarm_name          = "${var.name_prefix}-bedrock-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "InvocationLatency"
  namespace           = "AWS/Bedrock"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 5000  # 5 seconds
  alarm_description   = "Warning: Bedrock p95 latency exceeded 5 seconds"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.warning.arn]
  ok_actions    = [aws_sns_topic.info.arn]

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Connect Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "connect_call_failures" {
  count = var.connect_instance_id != null ? 1 : 0

  alarm_name          = "${var.name_prefix}-connect-call-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CallsBreachingConcurrencyQuota"
  namespace           = "AWS/Connect"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Critical: Connect calls hitting concurrency limits"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.connect_instance_id
  }

  alarm_actions = [aws_sns_topic.critical.arn]
  ok_actions    = [aws_sns_topic.info.arn]

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Anomaly Detection Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_invocations_anomaly" {
  for_each = var.enable_anomaly_detection ? var.lambda_function_names : {}

  alarm_name          = "${var.name_prefix}-${each.key}-invocations-anomaly"
  comparison_operator = "LessThanLowerOrGreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "ad1"
  alarm_description   = "Anomaly detected in Lambda ${each.key} invocations"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "m1"
    return_data = true

    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"

      dimensions = {
        FunctionName = each.value
      }
    }
  }

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    label       = "Invocations (expected)"
    return_data = true
  }

  alarm_actions = [aws_sns_topic.warning.arn]
  ok_actions    = [aws_sns_topic.info.arn]

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# DLQ Alarm (Messages in Dead Letter Queue)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  for_each = var.dlq_arns

  alarm_name          = "${var.name_prefix}-dlq-${each.key}-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Critical: Messages in DLQ for ${each.key}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = each.value
  }

  alarm_actions = [aws_sns_topic.critical.arn]

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Budget/Cost Alarm
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  count = var.monthly_budget_usd > 0 ? 1 : 0

  alarm_name          = "${var.name_prefix}-estimated-charges"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600  # 6 hours
  statistic           = "Maximum"
  threshold           = var.monthly_budget_usd * 0.8  # 80% threshold
  alarm_description   = "Warning: AWS charges approaching budget"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.warning.arn]

  tags = var.common_tags
}
