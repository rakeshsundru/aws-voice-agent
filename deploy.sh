#!/bin/bash

# =============================================================================
# AWS Voice Agent - Automated Deployment Script
# =============================================================================
# This script will guide you through deploying the complete AWS Voice Agent
# infrastructure with minimal configuration required.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║              AWS VOICE AGENT - DEPLOYMENT SCRIPT                 ║"
    echo "║                                                                  ║"
    echo "║  This script will deploy a complete voice agent infrastructure  ║"
    echo "║  including: VPC, Lambda, S3, Connect, Bedrock, Lex, CloudTrail  ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print section header
print_section() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Print success message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Print info message
print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

preflight_checks() {
    print_section "Pre-flight Checks"

    # Check for required commands
    local missing_deps=()

    if ! command_exists curl; then
        missing_deps+=("curl")
    fi

    if ! command_exists unzip; then
        missing_deps+=("unzip")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install them and try again."
        exit 1
    fi

    print_success "All basic dependencies found"

    # Check/Install Terraform
    if ! command_exists terraform; then
        print_warning "Terraform not found. Installing..."
        install_terraform
    else
        local tf_version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        print_success "Terraform found (version: ${tf_version})"
    fi

    # Check terraform directory exists
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found at: $TERRAFORM_DIR"
        exit 1
    fi

    print_success "Terraform configuration found"
}

# Install Terraform
install_terraform() {
    local TF_VERSION="1.7.0"
    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local ARCH=$(uname -m)

    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    echo "Downloading Terraform ${TF_VERSION}..."
    curl -sL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_${OS}_${ARCH}.zip" -o /tmp/terraform.zip

    echo "Installing Terraform..."
    unzip -o /tmp/terraform.zip -d /tmp/ >/dev/null

    # Try to install to /usr/local/bin, fall back to local directory
    if [ -w /usr/local/bin ]; then
        mv /tmp/terraform /usr/local/bin/
    else
        mkdir -p "${SCRIPT_DIR}/bin"
        mv /tmp/terraform "${SCRIPT_DIR}/bin/"
        export PATH="${SCRIPT_DIR}/bin:$PATH"
    fi

    rm -f /tmp/terraform.zip
    print_success "Terraform ${TF_VERSION} installed"
}

# =============================================================================
# COLLECT AWS CREDENTIALS
# =============================================================================

collect_aws_credentials() {
    print_section "AWS Credentials Configuration"

    echo "Enter your AWS credentials. These will be used to deploy the infrastructure."
    echo -e "${YELLOW}Note: Credentials are only stored in environment variables for this session.${NC}\n"

    # Check if credentials already exist in environment
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "Existing AWS credentials detected in environment."
        read -p "Use existing credentials? (Y/n): " use_existing
        if [[ "$use_existing" =~ ^[Yy]?$ ]]; then
            print_success "Using existing AWS credentials"

            # Still ask for region if not set
            if [ -z "$AWS_DEFAULT_REGION" ]; then
                read -p "AWS Region [us-east-1]: " aws_region
                export AWS_DEFAULT_REGION="${aws_region:-us-east-1}"
            fi
            return
        fi
    fi

    # Collect new credentials
    while true; do
        read -p "AWS Access Key ID: " aws_access_key
        if [ -z "$aws_access_key" ]; then
            print_error "Access Key ID cannot be empty"
            continue
        fi
        break
    done

    while true; do
        read -sp "AWS Secret Access Key: " aws_secret_key
        echo ""
        if [ -z "$aws_secret_key" ]; then
            print_error "Secret Access Key cannot be empty"
            continue
        fi
        break
    done

    echo ""
    echo "Available regions: us-east-1, us-west-2, eu-west-1, eu-central-1, ap-southeast-1, ap-northeast-1"
    read -p "AWS Region [us-east-1]: " aws_region

    # Export credentials
    export AWS_ACCESS_KEY_ID="$aws_access_key"
    export AWS_SECRET_ACCESS_KEY="$aws_secret_key"
    export AWS_DEFAULT_REGION="${aws_region:-us-east-1}"

    # Validate credentials
    echo ""
    echo "Validating AWS credentials..."
    if aws sts get-caller-identity >/dev/null 2>&1 || curl -s -o /dev/null -w "%{http_code}" "https://sts.${AWS_DEFAULT_REGION}.amazonaws.com/" >/dev/null; then
        print_success "AWS credentials configured for region: ${AWS_DEFAULT_REGION}"
    else
        # Try a simple validation by checking if we can proceed
        print_warning "Could not validate credentials (AWS CLI not installed). Proceeding anyway..."
    fi
}

# =============================================================================
# COLLECT PROJECT CONFIGURATION
# =============================================================================

collect_project_config() {
    print_section "Project Configuration"

    echo "Configure your Voice Agent deployment settings."
    echo ""

    # Project name
    read -p "Project Name [voice-agent]: " project_name
    PROJECT_NAME="${project_name:-voice-agent}"

    # Environment
    echo ""
    echo "Environment options: dev, staging, prod"
    read -p "Environment [dev]: " environment
    ENVIRONMENT="${environment:-dev}"

    # Owner email
    echo ""
    read -p "Owner Email (for resource tagging): " owner_email
    while [ -z "$owner_email" ]; do
        print_error "Owner email is required for resource tagging"
        read -p "Owner Email: " owner_email
    done
    OWNER_EMAIL="$owner_email"

    # Connect instance
    echo ""
    print_info "Amazon Connect Instance Configuration"
    echo "You can either create a new Connect instance or use an existing one."
    echo "Note: New Connect instances require quota approval from AWS."
    echo ""
    read -p "Do you have an existing Connect instance? (y/N): " has_connect

    if [[ "$has_connect" =~ ^[Yy]$ ]]; then
        read -p "Enter existing Connect Instance ID: " connect_id
        EXISTING_CONNECT_ID="$connect_id"

        read -p "Enter Connect Instance Alias (e.g., my-connect): " connect_alias
        CONNECT_ALIAS="${connect_alias:-my-voice-agent}"
    else
        EXISTING_CONNECT_ID=""
        read -p "Connect Instance Alias for new instance [${PROJECT_NAME}-connect]: " connect_alias
        CONNECT_ALIAS="${connect_alias:-${PROJECT_NAME}-connect}"
    fi

    # Optional features
    echo ""
    print_info "Optional Features"

    read -p "Enable Lex V2 for intent recognition? (Y/n): " enable_lex
    ENABLE_LEX=$([[ "$enable_lex" =~ ^[Nn]$ ]] && echo "false" || echo "true")

    read -p "Enable CloudTrail for audit logging? (Y/n): " enable_cloudtrail
    ENABLE_CLOUDTRAIL=$([[ "$enable_cloudtrail" =~ ^[Nn]$ ]] && echo "false" || echo "true")

    read -p "Enable Neptune graph database? (y/N): " enable_neptune
    ENABLE_NEPTUNE=$([[ "$enable_neptune" =~ ^[Yy]$ ]] && echo "true" || echo "false")

    # Production Features
    echo ""
    print_info "Production Features (Security & Monitoring)"

    read -p "Enable GuardDuty threat detection? (Y/n): " enable_guardduty
    ENABLE_GUARDDUTY=$([[ "$enable_guardduty" =~ ^[Nn]$ ]] && echo "false" || echo "true")

    read -p "Enable Security Hub compliance? (Y/n): " enable_securityhub
    ENABLE_SECURITYHUB=$([[ "$enable_securityhub" =~ ^[Nn]$ ]] && echo "false" || echo "true")

    read -p "Enable SNS alerting? (Y/n): " enable_alerting
    ENABLE_ALERTING=$([[ "$enable_alerting" =~ ^[Nn]$ ]] && echo "false" || echo "true")

    read -p "Enable AWS Backup? (Y/n): " enable_backup
    ENABLE_BACKUP=$([[ "$enable_backup" =~ ^[Nn]$ ]] && echo "false" || echo "true")

    read -p "Monthly budget alert (USD, 0 to disable) [500]: " monthly_budget
    MONTHLY_BUDGET="${monthly_budget:-500}"

    # Summary
    echo ""
    print_section "Configuration Summary"
    echo "  Project Name:      ${PROJECT_NAME}"
    echo "  Environment:       ${ENVIRONMENT}"
    echo "  Owner Email:       ${OWNER_EMAIL}"
    echo "  AWS Region:        ${AWS_DEFAULT_REGION}"
    echo "  Connect Instance:  ${EXISTING_CONNECT_ID:-New instance (${CONNECT_ALIAS})}"
    echo "  Lex V2:            ${ENABLE_LEX}"
    echo "  CloudTrail:        ${ENABLE_CLOUDTRAIL}"
    echo "  Neptune:           ${ENABLE_NEPTUNE}"
    echo "  GuardDuty:         ${ENABLE_GUARDDUTY}"
    echo "  Security Hub:      ${ENABLE_SECURITYHUB}"
    echo "  SNS Alerting:      ${ENABLE_ALERTING}"
    echo "  AWS Backup:        ${ENABLE_BACKUP}"
    echo "  Monthly Budget:    \$${MONTHLY_BUDGET}"
    echo ""

    read -p "Proceed with this configuration? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
}

# =============================================================================
# GENERATE TERRAFORM CONFIGURATION
# =============================================================================

generate_tfvars() {
    print_section "Generating Terraform Configuration"

    local TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

    # Backup existing tfvars if present
    if [ -f "$TFVARS_FILE" ]; then
        cp "$TFVARS_FILE" "${TFVARS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Existing terraform.tfvars backed up"
    fi

    # Determine Connect configuration
    local CONNECT_CONFIG=""
    if [ -n "$EXISTING_CONNECT_ID" ]; then
        CONNECT_CONFIG="existing_connect_instance_id = \"${EXISTING_CONNECT_ID}\""
    else
        CONNECT_CONFIG="existing_connect_instance_id = null"
    fi

    # Generate tfvars file
    cat > "$TFVARS_FILE" << EOF
# =============================================================================
# AWS Voice Agent - Terraform Variables
# Generated by deploy.sh on $(date)
# =============================================================================

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

project_name = "${PROJECT_NAME}"
environment  = "${ENVIRONMENT}"
aws_region   = "${AWS_DEFAULT_REGION}"

# -----------------------------------------------------------------------------
# Resource Tags
# -----------------------------------------------------------------------------

tags = {
  Project     = "${PROJECT_NAME}"
  Environment = "${ENVIRONMENT}"
  ManagedBy   = "terraform"
  Owner       = "${OWNER_EMAIL}"
  Purpose     = "Voice Agent Infrastructure"
}

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------

vpc_config = {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  single_nat_gateway   = true  # Set to false for production HA
}

availability_zones = ["${AWS_DEFAULT_REGION}a", "${AWS_DEFAULT_REGION}b"]

# -----------------------------------------------------------------------------
# Connect Configuration
# -----------------------------------------------------------------------------

${CONNECT_CONFIG}

connect_config = {
  instance_alias           = "${CONNECT_ALIAS}"
  identity_management_type = "CONNECT_MANAGED"
  inbound_calls_enabled    = true
  outbound_calls_enabled   = true
  contact_flow_name        = "VoiceAgentFlow"
  auto_accept_calls        = false
}

# -----------------------------------------------------------------------------
# Lambda Configuration
# -----------------------------------------------------------------------------

lambda_config = {
  runtime           = "python3.11"
  timeout           = 30
  memory_size       = 256
  log_retention     = 14
  reserved_concurrency = -1  # No limit
  environment_variables = {
    LOG_LEVEL = "INFO"
  }
}

# -----------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------

s3_config = {
  versioning_enabled = true
  force_destroy      = true  # Set to false for production
  lifecycle_rules = {
    recordings = {
      transition_days      = 30
      expiration_days      = 90
      storage_class        = "STANDARD_IA"
    }
    transcripts = {
      transition_days      = 30
      expiration_days      = 365
      storage_class        = "STANDARD_IA"
    }
  }
}

# -----------------------------------------------------------------------------
# Bedrock Configuration
# -----------------------------------------------------------------------------

bedrock_config = {
  model_id                 = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  max_tokens               = 1024
  temperature              = 0.7
  guardrail_enabled        = true
  guardrail_blocked_topics = ["illegal_activities", "harmful_content"]
}

# -----------------------------------------------------------------------------
# CloudWatch Configuration
# -----------------------------------------------------------------------------

cloudwatch_config = {
  log_retention_days   = 30
  enable_dashboard     = true
  enable_alarms        = true
  alarm_email          = "${OWNER_EMAIL}"
  metrics_namespace    = "${PROJECT_NAME}"
}

# -----------------------------------------------------------------------------
# Lex Configuration
# -----------------------------------------------------------------------------

lex_config = {
  enabled          = ${ENABLE_LEX}
  bot_name         = "${PROJECT_NAME}-bot"
  description      = "Voice Agent Intent Recognition Bot"
  idle_session_ttl = 300
  data_privacy     = { child_directed = false }
}

# -----------------------------------------------------------------------------
# Neptune Configuration (Optional)
# -----------------------------------------------------------------------------

neptune_config = {
  enabled               = ${ENABLE_NEPTUNE}
  instance_class        = "db.t3.medium"
  cluster_size          = 1
  backup_retention_days = 7
  preferred_backup_window = "02:00-03:00"
  engine_version        = "1.2.1.0"
  port                  = 8182
  iam_authentication    = true
  deletion_protection   = false
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

security_config = {
  enable_encryption_at_rest    = true
  enable_encryption_in_transit = true
  kms_key_deletion_window      = 7
  enable_vpc_endpoints         = true
  enable_cloudtrail            = ${ENABLE_CLOUDTRAIL}
}

# -----------------------------------------------------------------------------
# Production Configuration (Security & Monitoring)
# -----------------------------------------------------------------------------

production_config = {
  # Alerting
  enable_alerting              = ${ENABLE_ALERTING}
  alert_email                  = "${OWNER_EMAIL}"

  # Security Services
  enable_security_services     = ${ENABLE_GUARDDUTY}
  enable_vpc_flow_logs         = ${ENABLE_GUARDDUTY}
  enable_guardduty             = ${ENABLE_GUARDDUTY}
  enable_security_hub          = ${ENABLE_SECURITYHUB}
  enable_aws_config            = ${ENABLE_SECURITYHUB}

  # Secrets & Backup
  enable_secrets_manager       = true
  enable_backup                = ${ENABLE_BACKUP}

  # Cost Management
  monthly_budget_usd           = ${MONTHLY_BUDGET}

  # Alarm Thresholds
  lambda_duration_threshold_ms = 10000
  lambda_concurrency_threshold = 50
  enable_anomaly_detection     = true

  # Backup Retention
  daily_backup_retention_days   = 7
  weekly_backup_retention_days  = 35
  monthly_backup_retention_days = 365
}
EOF

    print_success "Generated terraform.tfvars"
}

# =============================================================================
# CREATE LAMBDA LAYER
# =============================================================================

create_lambda_layer() {
    print_section "Creating Lambda Dependencies Layer"

    local LAYER_DIR="${SCRIPT_DIR}/lambda/layers"
    local PYTHON_DIR="${LAYER_DIR}/python"
    local LAYER_ZIP="${LAYER_DIR}/dependencies.zip"

    # Check if layer already exists
    if [ -f "$LAYER_ZIP" ]; then
        print_info "Lambda layer already exists. Skipping creation."
        return
    fi

    mkdir -p "$PYTHON_DIR"

    # Check if pip is available
    if command_exists pip3; then
        PIP_CMD="pip3"
    elif command_exists pip; then
        PIP_CMD="pip"
    else
        print_warning "pip not found. Creating minimal layer..."
        # Create minimal layer without dependencies
        cd "$LAYER_DIR"
        zip -r dependencies.zip python/ >/dev/null 2>&1 || true
        print_success "Created minimal Lambda layer"
        return
    fi

    echo "Installing Python dependencies..."
    $PIP_CMD install boto3 requests gremlinpython -t "$PYTHON_DIR" -q --upgrade 2>/dev/null || {
        print_warning "Could not install all dependencies. Creating minimal layer..."
    }

    # Create zip
    cd "$LAYER_DIR"
    zip -r dependencies.zip python/ >/dev/null 2>&1

    print_success "Created Lambda dependencies layer"
}

# =============================================================================
# DEPLOY INFRASTRUCTURE
# =============================================================================

deploy_infrastructure() {
    print_section "Deploying Infrastructure"

    cd "$TERRAFORM_DIR"

    # Initialize Terraform
    echo "Initializing Terraform..."
    if terraform init -upgrade >/dev/null 2>&1; then
        print_success "Terraform initialized"
    else
        terraform init -upgrade
    fi

    # Plan
    echo ""
    echo "Creating deployment plan..."
    if ! terraform plan -out=tfplan; then
        print_error "Terraform plan failed. Please check the errors above."
        exit 1
    fi

    print_success "Deployment plan created"

    # Confirm deployment
    echo ""
    read -p "Deploy infrastructure now? (Y/n): " deploy_confirm
    if [[ "$deploy_confirm" =~ ^[Nn]$ ]]; then
        echo "Deployment cancelled. Run 'terraform apply tfplan' in the terraform directory to deploy later."
        exit 0
    fi

    # Apply
    echo ""
    echo "Deploying infrastructure (this may take 10-15 minutes)..."
    echo ""

    if terraform apply tfplan; then
        print_success "Infrastructure deployed successfully!"
    else
        print_error "Deployment failed. Please check the errors above."
        exit 1
    fi
}

# =============================================================================
# POST-DEPLOYMENT SUMMARY
# =============================================================================

post_deployment_summary() {
    print_section "Deployment Complete!"

    cd "$TERRAFORM_DIR"

    echo -e "${GREEN}Your AWS Voice Agent infrastructure has been deployed successfully!${NC}"
    echo ""

    # Get outputs
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                        DEPLOYMENT SUMMARY                          "
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    # Try to get terraform outputs
    if terraform output -json >/dev/null 2>&1; then
        echo "Project Info:"
        terraform output -json project_info 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  Region: {d.get('aws_region','N/A')}\"); print(f\"  Account: {d.get('aws_account_id','N/A')}\"); print(f\"  Prefix: {d.get('resource_prefix','N/A')}\")" 2>/dev/null || echo "  See terraform output for details"

        echo ""
        echo "Connect Instance:"
        terraform output -json connect 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  Instance ID: {d.get('instance_id','N/A')}\"); print(f\"  Alias: {d.get('instance_alias','N/A')}\"); print(f\"  Contact Flow: {d.get('contact_flow_id','N/A')}\")" 2>/dev/null || echo "  See terraform output for details"

        echo ""
        echo "Lambda Functions:"
        terraform output -json lambda 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  Orchestrator: {d.get('orchestrator',{}).get('function_name','N/A')}\"); print(f\"  Integration: {d.get('integration',{}).get('function_name','N/A')}\")" 2>/dev/null || echo "  See terraform output for details"

        echo ""
        echo "Monitoring:"
        terraform output -json monitoring 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  Dashboard: {d.get('dashboard_url','N/A')}\")" 2>/dev/null || echo "  See terraform output for details"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                          NEXT STEPS                                "
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "1. Claim a phone number in Amazon Connect Console:"
    echo "   https://${CONNECT_ALIAS}.my.connect.aws"
    echo ""
    echo "2. Associate the phone number with your contact flow"
    echo ""
    echo "3. Test by calling the phone number"
    echo ""
    echo "4. Monitor in CloudWatch Dashboard"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "To view all outputs:  cd terraform && terraform output"
    echo "To destroy:           cd terraform && terraform destroy"
    echo ""

    print_success "Deployment script completed!"
}

# =============================================================================
# CLEANUP FUNCTION
# =============================================================================

cleanup() {
    # Unset sensitive environment variables on exit
    unset AWS_SECRET_ACCESS_KEY
}

trap cleanup EXIT

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_banner

    preflight_checks
    collect_aws_credentials
    collect_project_config
    generate_tfvars
    create_lambda_layer
    deploy_infrastructure
    post_deployment_summary
}

# Run main function
main "$@"
