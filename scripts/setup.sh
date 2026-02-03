#!/bin/bash
# =============================================================================
# AWS Voice Agent - Initial Setup Script
# =============================================================================
# Usage: ./setup.sh [environment]
# Example: ./setup.sh dev
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

# Default environment
ENVIRONMENT="${1:-dev}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AWS Voice Agent Initial Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    local missing=()

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        missing+=("AWS CLI")
    fi

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        missing+=("Terraform")
    fi

    # Check Python
    if ! command -v python3 &> /dev/null; then
        missing+=("Python 3")
    fi

    # Check pip
    if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
        missing+=("pip")
    fi

    # Check jq (optional but helpful)
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq not installed (optional but recommended)${NC}"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required tools:${NC}"
        for tool in "${missing[@]}"; do
            echo -e "  - $tool"
        done
        echo ""
        echo "Please install the missing tools and try again."
        exit 1
    fi

    echo -e "${GREEN}All prerequisites installed${NC}"
    echo ""
}

# Setup Python virtual environment
setup_python_env() {
    echo -e "${YELLOW}Setting up Python environment...${NC}"

    cd "$ROOT_DIR"

    # Create virtual environment if it doesn't exist
    if [[ ! -d ".venv" ]]; then
        python3 -m venv .venv
        echo "Created virtual environment"
    fi

    # Activate virtual environment
    source .venv/bin/activate

    # Upgrade pip
    pip install --upgrade pip --quiet

    # Install development dependencies
    pip install boto3 pytest pytest-cov moto responses pyyaml --quiet

    echo -e "${GREEN}Python environment ready${NC}"
    echo ""
}

# Setup AWS configuration
setup_aws() {
    echo -e "${YELLOW}Checking AWS configuration...${NC}"

    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}AWS credentials not configured${NC}"
        echo ""
        echo "Please configure AWS credentials using one of:"
        echo "  1. aws configure"
        echo "  2. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
        echo "  3. Use IAM role (if running on AWS)"
        exit 1
    fi

    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)

    echo "AWS Account: ${AWS_ACCOUNT}"
    echo "AWS Region: ${AWS_REGION}"
    echo "AWS User: ${AWS_USER}"
    echo -e "${GREEN}AWS configuration verified${NC}"
    echo ""
}

# Create configuration file from template
setup_config() {
    echo -e "${YELLOW}Setting up configuration...${NC}"

    CONFIG_FILE="${ROOT_DIR}/config/${ENVIRONMENT}.yaml"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Configuration file not found, copying from template..."
        cp "${ROOT_DIR}/config/dev.yaml" "$CONFIG_FILE"
        echo "Created ${CONFIG_FILE}"
        echo -e "${YELLOW}Please review and customize the configuration file${NC}"
    else
        echo "Configuration file exists: ${CONFIG_FILE}"
    fi

    # Create tfvars from yaml
    echo "Generating Terraform variables..."
    python3 << EOF
import yaml
import json
import os

config_file = "${CONFIG_FILE}"
tfvars_file = config_file.replace('.yaml', '.tfvars')

with open(config_file, 'r') as f:
    config = yaml.safe_load(f)

def to_tfvars(config, prefix=''):
    lines = []
    for key, value in config.items():
        var_name = f"{prefix}{key}" if prefix else key
        if isinstance(value, dict):
            # Convert nested dict to HCL format
            lines.append(f'{var_name} = {json.dumps(value)}')
        elif isinstance(value, list):
            lines.append(f'{var_name} = {json.dumps(value)}')
        elif isinstance(value, bool):
            lines.append(f'{var_name} = {str(value).lower()}')
        elif isinstance(value, (int, float)):
            lines.append(f'{var_name} = {value}')
        else:
            lines.append(f'{var_name} = "{value}"')
    return lines

# Map config to terraform variables
tf_vars = {
    'environment': config.get('environment', 'dev'),
    'aws_region': config.get('aws_region', 'us-east-1'),
    'project_name': config.get('project_name', 'voice-agent'),
    'resource_prefix': config.get('resource_prefix', ''),
    'bedrock_config': config.get('bedrock', {}),
    'connect_config': config.get('connect', {}),
    'neptune_config': config.get('neptune', {}),
    'transcribe_config': config.get('transcribe', {}),
    'lex_config': config.get('lex', {}),
    'polly_config': config.get('polly', {}),
    'lambda_config': config.get('lambda', {}),
    's3_config': config.get('s3', {}),
    'cloudwatch_config': config.get('cloudwatch', {}),
    'security_config': config.get('security', {}),
    'vpc_config': config.get('vpc', {}),
    'agent_config': config.get('agent', {}),
    'integration_config': config.get('integration', {}),
    'common_tags': config.get('tags', {}),
}

with open(tfvars_file, 'w') as f:
    for key, value in tf_vars.items():
        if isinstance(value, dict):
            f.write(f'{key} = {json.dumps(value, indent=2)}\n\n')
        elif isinstance(value, list):
            f.write(f'{key} = {json.dumps(value)}\n\n')
        elif isinstance(value, bool):
            f.write(f'{key} = {str(value).lower()}\n\n')
        elif isinstance(value, (int, float)):
            f.write(f'{key} = {value}\n\n')
        else:
            f.write(f'{key} = "{value}"\n\n')

print(f"Generated {tfvars_file}")
EOF

    echo -e "${GREEN}Configuration setup complete${NC}"
    echo ""
}

# Setup Lambda dependencies
setup_lambda() {
    echo -e "${YELLOW}Setting up Lambda dependencies...${NC}"

    LAMBDA_DIR="${ROOT_DIR}/lambda"

    # Create layers directory
    mkdir -p "${LAMBDA_DIR}/layers"

    # Install orchestrator dependencies
    cd "${LAMBDA_DIR}/orchestrator"
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt --quiet
        echo "Installed orchestrator dependencies"
    fi

    # Install integration dependencies
    cd "${LAMBDA_DIR}/integrations"
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt --quiet
        echo "Installed integration dependencies"
    fi

    echo -e "${GREEN}Lambda dependencies installed${NC}"
    echo ""
}

# Validate setup
validate_setup() {
    echo -e "${YELLOW}Validating setup...${NC}"

    cd "${ROOT_DIR}/terraform"

    # Validate Terraform configuration
    terraform init -backend=false > /dev/null 2>&1
    if terraform validate > /dev/null 2>&1; then
        echo -e "${GREEN}Terraform configuration valid${NC}"
    else
        echo -e "${RED}Terraform validation failed${NC}"
        terraform validate
        exit 1
    fi

    echo -e "${GREEN}Setup validation complete${NC}"
    echo ""
}

# Print next steps
print_next_steps() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Setup Complete!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Review and customize the configuration:"
    echo "   ${ROOT_DIR}/config/${ENVIRONMENT}.yaml"
    echo ""
    echo "2. Deploy the infrastructure:"
    echo "   ./scripts/deploy.sh ${ENVIRONMENT}"
    echo ""
    echo "3. After deployment, test the voice agent:"
    echo "   ./scripts/test_call.sh"
    echo ""
    echo "For more information, see:"
    echo "   ${ROOT_DIR}/docs/DEPLOYMENT.md"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    setup_python_env
    setup_aws
    setup_config
    setup_lambda
    validate_setup
    print_next_steps
}

# Run main
main
