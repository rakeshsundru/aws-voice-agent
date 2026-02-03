# =============================================================================
# Connect Module - Telephony Infrastructure
# =============================================================================

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Amazon Connect Instance
# -----------------------------------------------------------------------------

resource "aws_connect_instance" "main" {
  identity_management_type = var.identity_management_type
  inbound_calls_enabled    = var.inbound_calls_enabled
  outbound_calls_enabled   = var.outbound_calls_enabled
  instance_alias           = var.instance_alias

  # Note: Tags are not supported on Connect instances at the time of writing
}

# -----------------------------------------------------------------------------
# Enable Contact Flow Logs
# -----------------------------------------------------------------------------

resource "aws_connect_instance_storage_config" "contact_trace_records" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CONTACT_TRACE_RECORDS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = var.s3_bucket_recordings
      bucket_prefix = "ctr"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.kms_key_arn
      }
    }
  }
}

resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = var.s3_bucket_recordings
      bucket_prefix = "recordings"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.kms_key_arn
      }
    }
  }
}

resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = var.s3_bucket_transcripts
      bucket_prefix = "transcripts"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.kms_key_arn
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Hours of Operation
# -----------------------------------------------------------------------------

resource "aws_connect_hours_of_operation" "main" {
  instance_id = aws_connect_instance.main.id
  name        = var.hours_of_operation != null ? var.hours_of_operation.name : "${var.name_prefix}-hours"
  description = "Hours of operation for ${var.name_prefix}"
  time_zone   = var.hours_of_operation != null ? var.hours_of_operation.time_zone : "America/New_York"

  dynamic "config" {
    for_each = var.hours_of_operation != null ? var.hours_of_operation.config : [
      # Default 24/7 operation
      { day = "MONDAY", start_time = "00:00", end_time = "23:59" },
      { day = "TUESDAY", start_time = "00:00", end_time = "23:59" },
      { day = "WEDNESDAY", start_time = "00:00", end_time = "23:59" },
      { day = "THURSDAY", start_time = "00:00", end_time = "23:59" },
      { day = "FRIDAY", start_time = "00:00", end_time = "23:59" },
      { day = "SATURDAY", start_time = "00:00", end_time = "23:59" },
      { day = "SUNDAY", start_time = "00:00", end_time = "23:59" }
    ]

    content {
      day = config.value.day
      start_time {
        hours   = tonumber(split(":", config.value.start_time)[0])
        minutes = tonumber(split(":", config.value.start_time)[1])
      }
      end_time {
        hours   = tonumber(split(":", config.value.end_time)[0])
        minutes = tonumber(split(":", config.value.end_time)[1])
      }
    }
  }

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Queue
# -----------------------------------------------------------------------------

resource "aws_connect_queue" "main" {
  instance_id           = aws_connect_instance.main.id
  name                  = "${var.name_prefix}-queue"
  description           = "Main queue for ${var.name_prefix}"
  hours_of_operation_id = aws_connect_hours_of_operation.main.hours_of_operation_id

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Routing Profile
# -----------------------------------------------------------------------------

resource "aws_connect_routing_profile" "main" {
  instance_id               = aws_connect_instance.main.id
  name                      = "${var.name_prefix}-routing"
  description               = "Routing profile for ${var.name_prefix}"
  default_outbound_queue_id = aws_connect_queue.main.queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.main.queue_id
  }

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Lambda Function Association
# -----------------------------------------------------------------------------

resource "aws_connect_lambda_function_association" "orchestrator" {
  instance_id  = aws_connect_instance.main.id
  function_arn = var.lambda_function_arn
}

# -----------------------------------------------------------------------------
# Contact Flow
# -----------------------------------------------------------------------------

resource "aws_connect_contact_flow" "inbound" {
  instance_id = aws_connect_instance.main.id
  name        = "${var.name_prefix}-inbound-flow"
  description = "Inbound contact flow for voice agent"
  type        = "CONTACT_FLOW"

  content = jsonencode({
    Version     = "2019-10-30"
    StartAction = "greeting"
    Actions = [
      {
        Identifier = "greeting"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "Welcome to our voice agent. How can I help you today?"
        }
        Transitions = {
          NextAction = "get_input"
          Errors = [
            {
              NextAction  = "error_handling"
              ErrorType   = "NoMatchingError"
            }
          ]
        }
      },
      {
        Identifier = "get_input"
        Type       = "GetParticipantInput"
        Parameters = {
          InputTimeLimitSeconds = "10"
          Text                  = ""
        }
        Transitions = {
          NextAction = "invoke_lambda"
          Conditions = []
          Errors = [
            {
              NextAction  = "no_input"
              ErrorType   = "InputTimeLimitExceeded"
            },
            {
              NextAction  = "error_handling"
              ErrorType   = "NoMatchingError"
            }
          ]
        }
      },
      {
        Identifier = "invoke_lambda"
        Type       = "InvokeLambdaFunction"
        Parameters = {
          LambdaFunctionARN = var.lambda_function_arn
          InvocationTimeLimitSeconds = "8"
        }
        Transitions = {
          NextAction = "speak_response"
          Errors = [
            {
              NextAction  = "lambda_error"
              ErrorType   = "NoMatchingError"
            }
          ]
        }
      },
      {
        Identifier = "speak_response"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "$.External.response"
        }
        Transitions = {
          NextAction = "check_continue"
          Errors = [
            {
              NextAction  = "error_handling"
              ErrorType   = "NoMatchingError"
            }
          ]
        }
      },
      {
        Identifier = "check_continue"
        Type       = "CheckAttribute"
        Parameters = {
          Attribute        = "$.External.action"
          ComparisonType   = "Equals"
          ComparisonValue  = "transfer"
        }
        Transitions = {
          NextAction = "get_input"
          Conditions = [
            {
              NextAction     = "transfer_to_agent"
              Condition = {
                Operator  = "Equals"
                Operands  = ["transfer"]
              }
            },
            {
              NextAction     = "end_call"
              Condition = {
                Operator  = "Equals"
                Operands  = ["end"]
              }
            }
          ]
          Errors = [
            {
              NextAction  = "get_input"
              ErrorType   = "NoMatchingCondition"
            }
          ]
        }
      },
      {
        Identifier = "no_input"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "I didn't hear anything. Could you please repeat that?"
        }
        Transitions = {
          NextAction = "get_input"
          Errors = [
            {
              NextAction  = "error_handling"
              ErrorType   = "NoMatchingError"
            }
          ]
        }
      },
      {
        Identifier = "lambda_error"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "I'm having trouble processing your request. Let me connect you to an agent."
        }
        Transitions = {
          NextAction = "transfer_to_agent"
          Errors = [
            {
              NextAction  = "end_call"
              ErrorType   = "NoMatchingError"
            }
          ]
        }
      },
      {
        Identifier = "error_handling"
        Type       = "MessageParticipant"
        Parameters = {
          Text = "Sorry, I encountered an error. Please try again later."
        }
        Transitions = {
          NextAction = "end_call"
          Errors = [
            {
              NextAction  = "end_call"
              ErrorType   = "NoMatchingError"
            }
          ]
        }
      },
      {
        Identifier = "transfer_to_agent"
        Type       = "TransferContactToQueue"
        Parameters = {
          QueueId = aws_connect_queue.main.queue_id
        }
        Transitions = {
          NextAction = "end_call"
          Errors = [
            {
              NextAction  = "end_call"
              ErrorType   = "NoMatchingError"
            }
          ]
        }
      },
      {
        Identifier = "end_call"
        Type       = "DisconnectParticipant"
        Parameters = {}
        Transitions = {}
      }
    ]
  })

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Phone Number (Optional)
# -----------------------------------------------------------------------------

resource "aws_connect_phone_number" "main" {
  count = var.claim_phone_number ? 1 : 0

  target_arn   = aws_connect_instance.main.arn
  country_code = var.phone_number_country
  type         = var.phone_number_type
  prefix       = var.phone_number_prefix

  tags = var.common_tags
}

# Associate phone number with contact flow
resource "aws_connect_phone_number_contact_flow" "main" {
  count = var.claim_phone_number ? 1 : 0

  phone_number_id = aws_connect_phone_number.main[0].id
  contact_flow_id = aws_connect_contact_flow.inbound.contact_flow_id
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for Contact Flow Logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "connect" {
  count = var.contact_flow_logs ? 1 : 0

  name              = "/aws/connect/${aws_connect_instance.main.id}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}
