# =============================================================================
# AWS Voice Agent - Terraform Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# General Information
# -----------------------------------------------------------------------------

output "project_info" {
  description = "Project identification information"
  value = {
    project_name    = var.project_name
    environment     = var.environment
    aws_region      = var.aws_region
    aws_account_id  = data.aws_caller_identity.current.account_id
    resource_prefix = local.name_prefix
  }
}

# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------

output "vpc" {
  description = "VPC infrastructure details"
  value = {
    vpc_id              = module.vpc.vpc_id
    private_subnet_ids  = module.vpc.private_subnet_ids
    public_subnet_ids   = module.vpc.public_subnet_ids
    nat_gateway_ips     = module.vpc.nat_gateway_ips
    vpc_endpoints       = module.vpc.vpc_endpoint_ids
  }
}

# -----------------------------------------------------------------------------
# Amazon Connect Outputs
# -----------------------------------------------------------------------------

output "connect" {
  description = "Amazon Connect instance details"
  value = {
    instance_id     = module.connect.instance_id
    instance_arn    = module.connect.instance_arn
    instance_alias  = module.connect.instance_alias
    phone_number    = module.connect.phone_number
    contact_flow_id = module.connect.contact_flow_id
    service_role    = module.connect.service_role
  }
}

# -----------------------------------------------------------------------------
# Lambda Outputs
# -----------------------------------------------------------------------------

output "lambda" {
  description = "Lambda function details"
  value = {
    orchestrator = {
      function_name = module.lambda.orchestrator_function_name
      function_arn  = module.lambda.orchestrator_function_arn
      version       = module.lambda.orchestrator_function_version
    }
    integration = {
      function_name = module.lambda.integration_function_name
      function_arn  = module.lambda.integration_function_arn
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Outputs
# -----------------------------------------------------------------------------

output "s3" {
  description = "S3 bucket details"
  value = {
    recordings = {
      bucket_name = module.s3.bucket_names["recordings"]
      bucket_arn  = module.s3.bucket_arns["recordings"]
    }
    transcripts = {
      bucket_name = module.s3.bucket_names["transcripts"]
      bucket_arn  = module.s3.bucket_arns["transcripts"]
    }
    artifacts = {
      bucket_name = module.s3.bucket_names["artifacts"]
      bucket_arn  = module.s3.bucket_arns["artifacts"]
    }
  }
}

# -----------------------------------------------------------------------------
# Bedrock Outputs
# -----------------------------------------------------------------------------

output "bedrock" {
  description = "Bedrock configuration details"
  value = {
    model_id       = var.bedrock_config.model_id
    guardrail_id   = module.bedrock.guardrail_id
    guardrail_arn  = module.bedrock.guardrail_arn
    knowledge_base_id = try(module.bedrock.knowledge_base_id, null)
  }
}

# -----------------------------------------------------------------------------
# Neptune Outputs (Phase 2)
# -----------------------------------------------------------------------------

output "neptune" {
  description = "Neptune cluster details (if enabled)"
  value = var.neptune_config.enabled ? {
    cluster_endpoint        = module.neptune[0].cluster_endpoint
    cluster_reader_endpoint = module.neptune[0].cluster_reader_endpoint
    cluster_port            = module.neptune[0].cluster_port
    cluster_arn             = module.neptune[0].cluster_arn
  } : null
}

# -----------------------------------------------------------------------------
# Monitoring Outputs
# -----------------------------------------------------------------------------

output "monitoring" {
  description = "CloudWatch monitoring details"
  value = {
    log_groups = {
      lambda  = module.cloudwatch.lambda_log_group_name
      connect = module.cloudwatch.connect_log_group_name
    }
    dashboard_url = module.cloudwatch.dashboard_url
    alarm_arns    = module.cloudwatch.alarm_arns
  }
}

# -----------------------------------------------------------------------------
# Security Outputs
# -----------------------------------------------------------------------------

output "security" {
  description = "Security resource details"
  value = {
    kms_keys = {
      s3         = module.kms.key_arns["s3"]
      lambda     = module.kms.key_arns["lambda"]
      cloudwatch = module.kms.key_arns["cloudwatch"]
      bedrock    = module.kms.key_arns["bedrock"]
    }
    iam_roles = {
      lambda  = module.iam.lambda_role_arn
      connect = module.iam.connect_role_arn
      bedrock = module.iam.bedrock_role_arn
    }
    security_groups = {
      lambda  = module.vpc.lambda_security_group_id
      neptune = module.vpc.neptune_security_group_id
    }
  }
}

# -----------------------------------------------------------------------------
# Quick Start Information
# -----------------------------------------------------------------------------

output "quick_start" {
  description = "Quick start information for using the voice agent"
  value = <<-EOT

    =========================================
    AWS Voice Agent Deployment Complete!
    =========================================

    Phone Number: ${module.connect.phone_number != null ? module.connect.phone_number : "Not claimed - claim in AWS Connect Console"}

    Connect Instance URL: https://${module.connect.instance_alias}.my.connect.aws
    Contact Flow ID: ${module.connect.contact_flow_id}

    To test your voice agent:
    1. Claim a phone number in Connect Console
    2. Associate it with contact flow: ${module.connect.contact_flow_id}
    3. Call the phone number
    4. The agent will respond

    Monitoring:
    - CloudWatch Dashboard: ${module.cloudwatch.dashboard_url}
    - Lambda Logs: /aws/lambda/${module.lambda.orchestrator_function_name}
    - Connect Logs: ${module.cloudwatch.connect_log_group_name}

    S3 Buckets:
    - Recordings: s3://${module.s3.bucket_names["recordings"]}
    - Transcripts: s3://${module.s3.bucket_names["transcripts"]}
    - Artifacts: s3://${module.s3.bucket_names["artifacts"]}

  EOT
}
