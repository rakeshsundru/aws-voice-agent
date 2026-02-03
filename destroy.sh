#!/bin/bash

# =============================================================================
# AWS Voice Agent - Destroy Script
# =============================================================================
# This script will destroy all AWS Voice Agent infrastructure.
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║              AWS VOICE AGENT - DESTROY SCRIPT                    ║"
echo "║                                                                  ║"
echo "║  WARNING: This will permanently delete all infrastructure!       ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for AWS credentials
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo -e "${YELLOW}AWS credentials not found in environment.${NC}"
    echo ""
    read -p "AWS Access Key ID: " aws_access_key
    read -sp "AWS Secret Access Key: " aws_secret_key
    echo ""
    read -p "AWS Region [us-east-1]: " aws_region

    export AWS_ACCESS_KEY_ID="$aws_access_key"
    export AWS_SECRET_ACCESS_KEY="$aws_secret_key"
    export AWS_DEFAULT_REGION="${aws_region:-us-east-1}"
fi

echo ""
echo -e "${YELLOW}This will destroy the following resources:${NC}"
echo "  - VPC and all networking components"
echo "  - Lambda functions"
echo "  - S3 buckets and their contents"
echo "  - KMS encryption keys"
echo "  - Amazon Connect contact flows"
echo "  - Lex bots"
echo "  - CloudTrail trails"
echo "  - CloudWatch dashboards and alarms"
echo "  - All IAM roles and policies"
echo ""

read -p "Are you ABSOLUTELY sure you want to destroy everything? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

echo ""
echo "Destroying infrastructure..."
echo ""

cd "$TERRAFORM_DIR"

# Run terraform destroy
if terraform destroy -auto-approve; then
    echo ""
    echo -e "${GREEN}✓ All infrastructure has been destroyed.${NC}"
else
    echo ""
    echo -e "${RED}✗ Destruction failed. Some resources may still exist.${NC}"
    echo "Run 'terraform destroy' manually to clean up remaining resources."
    exit 1
fi

# Cleanup local state
echo ""
read -p "Remove local Terraform state files? (y/N): " cleanup_state
if [[ "$cleanup_state" =~ ^[Yy]$ ]]; then
    rm -rf .terraform terraform.tfstate* tfplan .terraform.lock.hcl
    echo -e "${GREEN}✓ Local state files removed.${NC}"
fi

echo ""
echo "Cleanup complete!"
