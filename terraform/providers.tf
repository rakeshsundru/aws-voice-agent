# =============================================================================
# AWS Voice Agent - Terraform Providers Configuration
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Backend configuration - override per environment
  # backend "s3" {}
}

# Primary AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      var.common_tags,
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "terraform"
        Repository  = "aws-voice-agent"
      }
    )
  }
}

# Secondary provider for us-east-1 (required for some global resources)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = merge(
      var.common_tags,
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "terraform"
        Repository  = "aws-voice-agent"
      }
    )
  }
}
