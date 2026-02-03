# =============================================================================
# CloudWatch Module - Monitoring and Logging
# =============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Log Groups
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "connect" {
  name              = "/aws/connect/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "voice_agent" {
  name              = "/voice-agent/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# SNS Topic for Alarms (Optional)
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "alarms" {
  count = var.sns_topic_arn == null ? 1 : 0

  name              = "${var.name_prefix}-alarms"
  kms_master_key_id = var.kms_key_arn

  tags = var.common_tags
}

locals {
  sns_topic_arn = var.sns_topic_arn != null ? var.sns_topic_arn : (length(aws_sns_topic.alarms) > 0 ? aws_sns_topic.alarms[0].arn : null)
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "main" {
  count = var.dashboard_enabled ? 1 : 0

  dashboard_name = "${var.name_prefix}-voice-agent"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Overview metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "Lambda Invocations"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.name_prefix}-orchestrator", { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "Lambda Errors"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", "${var.name_prefix}-orchestrator", { stat = "Sum", period = 300, color = "#d62728" }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "Lambda Duration"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${var.name_prefix}-orchestrator", { stat = "Average", period = 300 }],
            ["...", { stat = "p99", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "Lambda Concurrent Executions"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", "${var.name_prefix}-orchestrator", { stat = "Maximum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      # Row 2: Bedrock metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Bedrock Invocations"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Bedrock", "Invocations", { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Bedrock Latency"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Bedrock", "InvocationLatency", { stat = "Average", period = 300 }],
            ["...", { stat = "p95", period = 300 }],
            ["...", { stat = "p99", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Bedrock Token Usage"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Bedrock", "InputTokenCount", { stat = "Sum", period = 300 }],
            ["AWS/Bedrock", "OutputTokenCount", { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      # Row 3: Connect metrics
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "Connect - Calls"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Connect", "CallsIncoming", { stat = "Sum", period = 300 }],
            ["AWS/Connect", "CallsHandled", { stat = "Sum", period = 300 }],
            ["AWS/Connect", "CallsAbandoned", { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "Connect - Call Duration"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Connect", "CallDuration", { stat = "Average", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "Connect - Active Calls"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Connect", "ConcurrentCalls", { stat = "Maximum", period = 60 }]
          ]
          view = "timeSeries"
        }
      },
      # Row 4: Custom metrics and logs
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "Recent Errors"
          region = data.aws_region.current.name
          query  = "SOURCE '/aws/lambda/${var.name_prefix}-orchestrator' | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          view   = "table"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "Custom Metrics - Voice Agent"
          region = data.aws_region.current.name
          metrics = [
            ["VoiceAgent", "TotalLatency", "Environment", var.environment, { stat = "Average", period = 300 }],
            ["VoiceAgent", "STTLatency", "Environment", var.environment, { stat = "Average", period = 300 }],
            ["VoiceAgent", "LLMLatency", "Environment", var.environment, { stat = "Average", period = 300 }],
            ["VoiceAgent", "TTSLatency", "Environment", var.environment, { stat = "Average", period = 300 }]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

# High Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.name_prefix}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.alarms_config != null ? var.alarms_config.error_rate_threshold_percent : 5
  alarm_description   = "High error rate detected in voice agent"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.name_prefix}-orchestrator"
      }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.name_prefix}-orchestrator"
      }
    }
  }

  alarm_actions = local.sns_topic_arn != null ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != null ? [local.sns_topic_arn] : []

  tags = var.common_tags
}

# High Latency Alarm
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.name_prefix}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p95"
  threshold           = var.alarms_config != null ? var.alarms_config.latency_threshold_ms : 2000
  alarm_description   = "High latency detected in voice agent"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${var.name_prefix}-orchestrator"
  }

  alarm_actions = local.sns_topic_arn != null ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != null ? [local.sns_topic_arn] : []

  tags = var.common_tags
}

# Concurrent Executions Alarm
resource "aws_cloudwatch_metric_alarm" "high_concurrency" {
  alarm_name          = "${var.name_prefix}-high-concurrency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.alarms_config != null ? var.alarms_config.concurrent_calls_threshold : 100
  alarm_description   = "High concurrent executions - approaching capacity"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${var.name_prefix}-orchestrator"
  }

  alarm_actions = local.sns_topic_arn != null ? [local.sns_topic_arn] : []

  tags = var.common_tags
}

# Lambda Throttles Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.name_prefix}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${var.name_prefix}-orchestrator"
  }

  alarm_actions = local.sns_topic_arn != null ? [local.sns_topic_arn] : []

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Log Metric Filters
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.name_prefix}-error-count"
  pattern        = "ERROR"
  log_group_name = aws_cloudwatch_log_group.lambda.name

  metric_transformation {
    name          = "ErrorCount"
    namespace     = "VoiceAgent/${var.environment}"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "cold_start" {
  name           = "${var.name_prefix}-cold-start"
  pattern        = "\"COLD START\""
  log_group_name = aws_cloudwatch_log_group.lambda.name

  metric_transformation {
    name          = "ColdStarts"
    namespace     = "VoiceAgent/${var.environment}"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "timeout" {
  name           = "${var.name_prefix}-timeout"
  pattern        = "\"Task timed out\""
  log_group_name = aws_cloudwatch_log_group.lambda.name

  metric_transformation {
    name          = "Timeouts"
    namespace     = "VoiceAgent/${var.environment}"
    value         = "1"
    default_value = "0"
  }
}

# -----------------------------------------------------------------------------
# Log Insights Queries (Saved Queries)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_query_definition" "error_analysis" {
  name = "${var.name_prefix}/Error Analysis"

  log_group_names = [
    aws_cloudwatch_log_group.lambda.name
  ]

  query_string = <<-EOT
    filter @message like /ERROR/
    | parse @message /ERROR.*?(?<error_type>[A-Za-z]+Error)/
    | stats count(*) as error_count by error_type
    | sort error_count desc
    | limit 20
  EOT
}

resource "aws_cloudwatch_query_definition" "latency_analysis" {
  name = "${var.name_prefix}/Latency Analysis"

  log_group_names = [
    aws_cloudwatch_log_group.lambda.name
  ]

  query_string = <<-EOT
    filter @type = "REPORT"
    | stats
        avg(@duration) as avg_duration,
        pct(@duration, 50) as p50,
        pct(@duration, 90) as p90,
        pct(@duration, 95) as p95,
        pct(@duration, 99) as p99,
        max(@duration) as max_duration
      by bin(5m)
    | sort @timestamp desc
  EOT
}

resource "aws_cloudwatch_query_definition" "call_flow_analysis" {
  name = "${var.name_prefix}/Call Flow Analysis"

  log_group_names = [
    aws_cloudwatch_log_group.lambda.name
  ]

  query_string = <<-EOT
    filter @message like /session_id/
    | parse @message /session_id[\":\s]+(?<session_id>[a-zA-Z0-9-]+)/
    | parse @message /action[\":\s]+(?<action>[a-zA-Z_]+)/
    | stats count(*) as action_count by session_id, action
    | sort session_id, @timestamp
  EOT
}
