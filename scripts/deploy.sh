#!/bin/bash
# =============================================================================
# AWS Voice Agent - Deployment Script
# =============================================================================
# Usage: ./deploy.sh <environment> [--auto-approve] [--destroy]
# Example: ./deploy.sh dev
#          ./deploy.sh prod --auto-approve
#          ./deploy.sh dev --destroy
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
AUTO_APPROVE=""
DESTROY=""
ENVIRONMENT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            AUTO_APPROVE="-auto-approve"
            shift
            ;;
        --destroy)
            DESTROY="true"
            shift
            ;;
        *)
            if [[ -z "$ENVIRONMENT" ]]; then
                ENVIRONMENT="$1"
            fi
            shift
            ;;
    esac
done

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
    echo -e "${RED}Error: Environment is required${NC}"
    echo "Usage: ./deploy.sh <environment> [--auto-approve] [--destroy]"
    echo "Environments: dev, staging, prod"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be dev, staging, or prod${NC}"
    exit 1
fi

# Configuration file
CONFIG_FILE="${ROOT_DIR}/config/${ENVIRONMENT}.yaml"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: Configuration file not found: ${CONFIG_FILE}${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AWS Voice Agent Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Environment: ${GREEN}${ENVIRONMENT}${NC}"
echo -e "Config file: ${CONFIG_FILE}"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI is not installed${NC}"
        exit 1
    fi

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed${NC}"
        exit 1
    fi

    # Check Terraform version
    TF_VERSION=$(terraform version -json | python3 -c "import sys, json; print(json.load(sys.stdin)['terraform_version'])")
    echo -e "Terraform version: ${TF_VERSION}"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured${NC}"
        exit 1
    fi

    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    echo -e "AWS Account: ${AWS_ACCOUNT}"
    echo -e "AWS Region: ${AWS_REGION}"

    echo -e "${GREEN}Prerequisites check passed${NC}"
    echo ""
}

# Function to prepare Lambda packages
prepare_lambda() {
    echo -e "${YELLOW}Preparing Lambda packages...${NC}"

    LAMBDA_DIR="${ROOT_DIR}/lambda"

    # Create layers directory if it doesn't exist
    mkdir -p "${LAMBDA_DIR}/layers"

    # Package orchestrator
    echo "Packaging orchestrator function..."
    cd "${LAMBDA_DIR}/orchestrator"
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt -t package/ --quiet
        cp *.py package/
        cd package && zip -r ../orchestrator.zip . -x "*.pyc" -x "__pycache__/*" --quiet
        cd ..
        rm -rf package
    fi

    # Package integrations
    echo "Packaging integrations function..."
    cd "${LAMBDA_DIR}/integrations"
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt -t package/ --quiet
        cp *.py package/
        cd package && zip -r ../integrations.zip . -x "*.pyc" -x "__pycache__/*" --quiet
        cd ..
        rm -rf package
    fi

    # Create dependencies layer
    echo "Creating dependencies layer..."
    cd "${LAMBDA_DIR}"
    mkdir -p layer/python
    pip install boto3 requests gremlin-python -t layer/python --quiet
    cd layer && zip -r ../layers/dependencies.zip . -x "*.pyc" -x "__pycache__/*" --quiet
    cd ..
    rm -rf layer

    echo -e "${GREEN}Lambda packages prepared${NC}"
    echo ""
}

# Function to initialize Terraform
init_terraform() {
    echo -e "${YELLOW}Initializing Terraform...${NC}"

    cd "${ROOT_DIR}/terraform"

    # Create environment directory if needed
    mkdir -p "environments/${ENVIRONMENT}"

    # Create backend config for environment
    cat > "environments/${ENVIRONMENT}/backend.tf" << EOF
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF

    # Create environment tfvars
    cat > "environments/${ENVIRONMENT}/terraform.tfvars" << EOF
# Auto-generated from config/${ENVIRONMENT}.yaml
# Modify config file and re-run deployment to update
EOF

    # Initialize
    terraform init -reconfigure

    echo -e "${GREEN}Terraform initialized${NC}"
    echo ""
}

# Function to plan deployment
plan_deployment() {
    echo -e "${YELLOW}Planning deployment...${NC}"

    cd "${ROOT_DIR}/terraform"

    terraform plan \
        -var="environment=${ENVIRONMENT}" \
        -var-file="${ROOT_DIR}/config/${ENVIRONMENT}.tfvars" \
        -out=tfplan \
        2>&1 | tee plan_output.txt

    echo ""
    echo -e "${GREEN}Plan complete. Review the changes above.${NC}"
    echo ""
}

# Function to apply deployment
apply_deployment() {
    echo -e "${YELLOW}Applying deployment...${NC}"

    cd "${ROOT_DIR}/terraform"

    if [[ -n "$AUTO_APPROVE" ]]; then
        terraform apply $AUTO_APPROVE tfplan
    else
        read -p "Apply this plan? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo -e "${YELLOW}Deployment cancelled${NC}"
            exit 0
        fi
        terraform apply tfplan
    fi

    echo -e "${GREEN}Deployment complete${NC}"
    echo ""
}

# Function to destroy deployment
destroy_deployment() {
    echo -e "${RED}WARNING: This will destroy all resources in ${ENVIRONMENT}${NC}"

    if [[ -z "$AUTO_APPROVE" ]]; then
        read -p "Are you sure you want to destroy? Type 'destroy' to confirm: " confirm
        if [[ "$confirm" != "destroy" ]]; then
            echo -e "${YELLOW}Destruction cancelled${NC}"
            exit 0
        fi
    fi

    cd "${ROOT_DIR}/terraform"

    terraform destroy \
        -var="environment=${ENVIRONMENT}" \
        -var-file="${ROOT_DIR}/config/${ENVIRONMENT}.tfvars" \
        $AUTO_APPROVE

    echo -e "${GREEN}Destruction complete${NC}"
}

# Function to output deployment info
output_info() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Deployment Information${NC}"
    echo -e "${BLUE}========================================${NC}"

    cd "${ROOT_DIR}/terraform"

    terraform output -json | python3 -c "
import json
import sys

data = json.load(sys.stdin)

if 'quick_start' in data:
    print(data['quick_start']['value'])
else:
    for key, value in data.items():
        if isinstance(value.get('value'), dict):
            print(f'{key}:')
            for k, v in value['value'].items():
                print(f'  {k}: {v}')
        else:
            print(f'{key}: {value.get(\"value\", \"N/A\")}')
"
}

# Main execution
main() {
    check_prerequisites

    if [[ "$DESTROY" == "true" ]]; then
        destroy_deployment
    else
        prepare_lambda
        init_terraform
        plan_deployment
        apply_deployment
        output_info
    fi
}

# Run main
main
