# AWS Voice Agent

> A production-ready, AI-powered phone system that lets callers have natural conversations instead of pressing buttons.

---

## What Is This?

This repository contains everything you need to deploy an **intelligent voice agent** on AWS. When someone calls your phone number, instead of hearing "Press 1 for sales, press 2 for support...", they can simply speak naturally:

- **Caller**: "Hi, I'd like to schedule an appointment for next Tuesday"
- **Agent**: "Of course! I can help you with that. What time works best for you?"

### How It Works

```
    Customer calls your number
              │
              ▼
    ┌─────────────────┐
    │ Amazon Connect  │  ← Answers the phone
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   Transcribe    │  ← Converts speech to text
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Lambda + Claude │  ← Understands intent, generates response
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │     Polly       │  ← Converts text back to speech
    └────────┬────────┘
             │
             ▼
    Customer hears the response
```

### What You Get

After deployment, you will have:
- A **working phone number** that answers calls with AI
- A **CloudWatch dashboard** to monitor calls and performance
- **Call recordings** stored in S3 for review
- **Transcripts** of every conversation
- **Customizable prompts** to control how the agent behaves

---

## Prerequisites Checklist

Before you begin, make sure you have **ALL** of the following. The deployment **will fail** if any are missing.

### 1. AWS Account with Admin Access

You need an AWS account where you have **administrator permissions** (or at minimum, permissions to create IAM roles, Lambda functions, S3 buckets, and Amazon Connect instances).

**How to verify:**
```bash
# Run this command - it should show your account info, not an error
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

**If you see an error:** Your AWS credentials are not configured. See [AWS CLI Configuration](#aws-cli-configuration) below.

---

### 2. AWS CLI (version 2.x)

The AWS Command Line Interface lets you interact with AWS from your terminal.

**How to check if installed:**
```bash
aws --version
```

**Expected output (version 2.x required):**
```
aws-cli/2.15.0 Python/3.11.6 Darwin/23.0.0 source/arm64 prompt/off
```

**How to install (if not installed):**

| Operating System | Installation Command |
|-----------------|---------------------|
| **macOS** | `brew install awscli` |
| **Ubuntu/Debian** | `sudo apt-get install awscli` |
| **Amazon Linux/RHEL** | `sudo yum install awscli` |
| **Windows** | Download from [AWS CLI Installer](https://aws.amazon.com/cli/) |

**After installing, configure your credentials:**
```bash
aws configure
```

You will be prompted for:
```
AWS Access Key ID [None]: YOUR_ACCESS_KEY_HERE
AWS Secret Access Key [None]: YOUR_SECRET_KEY_HERE
Default region name [None]: us-east-1
Default output format [None]: json
```

> **Where do I get Access Keys?** Go to AWS Console → IAM → Users → Your User → Security Credentials → Create Access Key

---

### 3. Terraform (version 1.5.0 or higher)

Terraform creates all the AWS infrastructure automatically.

**How to check if installed:**
```bash
terraform --version
```

**Expected output:**
```
Terraform v1.7.0
on darwin_arm64
```

**How to install (if not installed):**

| Operating System | Installation Command |
|-----------------|---------------------|
| **macOS** | `brew install terraform` |
| **Ubuntu/Debian** | See [Terraform Install Guide](https://developer.hashicorp.com/terraform/install) |
| **Windows** | `choco install terraform` or download from HashiCorp |

---

### 4. Python (version 3.11 or higher)

Python is required for the Lambda functions.

**How to check if installed:**
```bash
python3 --version
```

**Expected output:**
```
Python 3.11.6
```

**How to install (if not installed):**

| Operating System | Installation Command |
|-----------------|---------------------|
| **macOS** | `brew install python@3.11` |
| **Ubuntu/Debian** | `sudo apt-get install python3.11 python3.11-venv` |
| **Windows** | Download from [python.org](https://www.python.org/downloads/) |

---

### 5. pip (Python package manager)

**How to check if installed:**
```bash
pip3 --version
```

**Expected output:**
```
pip 23.3.1 from /usr/local/lib/python3.11/site-packages/pip (python 3.11)
```

**How to install (if not installed):**
```bash
python3 -m ensurepip --upgrade
```

---

### 6. Git

**How to check if installed:**
```bash
git --version
```

**Expected output:**
```
git version 2.42.0
```

**How to install (if not installed):**

| Operating System | Installation Command |
|-----------------|---------------------|
| **macOS** | `xcode-select --install` |
| **Ubuntu/Debian** | `sudo apt-get install git` |
| **Windows** | Download from [git-scm.com](https://git-scm.com/download/win) |

---

### Prerequisites Verification Script

Run this to check everything at once:

```bash
echo "=== Checking Prerequisites ==="
echo ""
echo "1. AWS CLI:"
aws --version 2>/dev/null || echo "   ❌ NOT INSTALLED"
echo ""
echo "2. AWS Credentials:"
aws sts get-caller-identity 2>/dev/null && echo "   ✅ Configured" || echo "   ❌ NOT CONFIGURED"
echo ""
echo "3. Terraform:"
terraform --version 2>/dev/null | head -1 || echo "   ❌ NOT INSTALLED"
echo ""
echo "4. Python:"
python3 --version 2>/dev/null || echo "   ❌ NOT INSTALLED"
echo ""
echo "5. pip:"
pip3 --version 2>/dev/null || echo "   ❌ NOT INSTALLED"
echo ""
echo "6. Git:"
git --version 2>/dev/null || echo "   ❌ NOT INSTALLED"
echo ""
echo "=== Check Complete ==="
```

**All items must show a version number (not "NOT INSTALLED") before proceeding.**

---

## Step-by-Step Deployment Guide

There are **two ways** to deploy this project:

| Method | Best For | Command |
|--------|----------|---------|
| **Interactive (Recommended)** | First-time users, guided setup | `./deploy.sh` |
| **Config-based** | CI/CD, advanced users | `./scripts/deploy.sh dev` |

---

### Option A: Interactive Deployment (Recommended)

This method walks you through all configuration options with prompts.

#### Step 1: Clone and Enter the Repository

```bash
git clone https://github.com/your-org/aws-voice-agent.git
cd aws-voice-agent
```

#### Step 2: Run the Interactive Deployment Script

```bash
./deploy.sh
```

The script will prompt you for:
- Project name and environment
- AWS region
- Owner email (for alerts)
- Amazon Connect configuration
- Optional features (Lex, CloudTrail, Neptune)
- Production features (GuardDuty, Security Hub, Backup)

#### Step 3: Wait for Deployment

The script will:
1. Generate `terraform/terraform.tfvars` based on your inputs
2. Create Lambda layer dependencies
3. Initialize and apply Terraform

**Deployment takes 10-20 minutes.**

#### Step 4: Test Your Voice Agent

After deployment completes, you'll see output with your Connect instance details. Configure a phone number in the Amazon Connect console to test.

#### To Destroy

```bash
./destroy.sh
```

---

### Option B: Config-Based Deployment

This method uses YAML configuration files for reproducible deployments.

#### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/aws-voice-agent.git
```

**Expected output:**
```
Cloning into 'aws-voice-agent'...
remote: Enumerating objects: 100, done.
remote: Counting objects: 100% (100/100), done.
remote: Compressing objects: 100% (80/80), done.
Receiving objects: 100% (100/100), 150.00 KiB | 2.00 MiB/s, done.
Resolving deltas: 100% (20/20), done.
```

**Then enter the directory:**
```bash
cd aws-voice-agent
```

**Verify you're in the right place:**
```bash
ls -la
```

**You should see:**
```
drwxr-xr-x  config/
drwxr-xr-x  terraform/
drwxr-xr-x  lambda/
drwxr-xr-x  bedrock/
drwxr-xr-x  scripts/
-rw-r--r--  README.md
...
```

---

### Step 2: Choose Your AWS Region

**Important:** Amazon Connect and Bedrock are not available in all regions.

**Supported regions for this project:**
| Region | Location | Recommended |
|--------|----------|-------------|
| `us-east-1` | N. Virginia | ✅ Yes (most services available) |
| `us-west-2` | Oregon | ✅ Yes |
| `eu-west-2` | London | ⚠️ Limited Bedrock models |
| `ap-southeast-2` | Sydney | ⚠️ Limited Bedrock models |

**We recommend `us-east-1`** for the best experience.

**Verify your AWS CLI is set to the correct region:**
```bash
aws configure get region
```

**If you need to change it:**
```bash
aws configure set region us-east-1
```

---

### Step 3: Configure Your Deployment

Open the configuration file for your environment:

**For development/testing:**
```bash
# Using any text editor (nano, vim, VS Code, etc.)
nano config/dev.yaml

# Or with VS Code:
code config/dev.yaml
```

**Key settings to customize:**

```yaml
# config/dev.yaml

# REQUIRED: Change this to a unique name (lowercase, no spaces)
connect:
  instance_alias: my-company-voice-agent-dev  # ← Change "my-company" to your company

# REQUIRED: Change this to your company name
agent:
  company_name: "My Company Name"  # ← This is what the agent will say

# OPTIONAL: Customize the greeting
  greeting_message: "Hello! Thank you for calling My Company. How can I help you today?"
```

**Save the file** (in nano: `Ctrl+O`, then `Enter`, then `Ctrl+X`)

---

### Step 4: Run the Setup Script

This script validates your environment and prepares everything for deployment.

```bash
./scripts/setup.sh dev
```

**Expected output:**
```
========================================
AWS Voice Agent Initial Setup
========================================

Checking prerequisites...
✅ AWS CLI installed
✅ Terraform installed
✅ Python installed
✅ AWS credentials configured

Setting up Python environment...
✅ Virtual environment created
✅ Dependencies installed

Checking AWS configuration...
AWS Account: 123456789012
AWS Region: us-east-1
✅ AWS configuration verified

Setting up configuration...
✅ Configuration file exists
✅ Terraform variables generated

========================================
Setup Complete!
========================================

Next steps:
  ./scripts/deploy.sh dev
```

**If you see any ❌ errors, STOP and fix them before continuing.**

---

### Step 5: Deploy the Infrastructure

This is the main deployment step. It will create all AWS resources.

```bash
./scripts/deploy.sh dev
```

**What happens during deployment:**

1. **Lambda packages are created** (takes ~30 seconds)
2. **Terraform initializes** (takes ~10 seconds)
3. **Terraform plans the deployment** (takes ~30 seconds)
4. **You will see a plan summary** like this:

```
Plan: 47 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

5. **Type `yes` and press Enter**

6. **Resources are created** (takes 5-15 minutes)

**Expected final output:**
```
Apply complete! Resources: 47 added, 0 changed, 0 destroyed.

=========================================
AWS Voice Agent Deployment Complete!
=========================================

Phone Number: +1-555-123-4567  ← YOUR NEW PHONE NUMBER

To test your voice agent:
1. Call the phone number above
2. Speak your request
3. The agent will respond

Monitoring:
- CloudWatch Dashboard: https://us-east-1.console.aws.amazon.com/cloudwatch/...

S3 Buckets:
- Recordings: s3://va-dev-recordings-a1b2c3d4
- Transcripts: s3://va-dev-transcripts-a1b2c3d4
```

**Write down the phone number!** You'll need it to test.

---

### Step 6: Test Your Voice Agent

**Call the phone number** shown in the deployment output.

**What you should experience:**

1. **The call connects** (1-2 rings)
2. **You hear a greeting**: "Hello! Thank you for calling [Your Company]. How can I help you today?"
3. **Speak naturally**: "I'd like to know your business hours"
4. **The agent responds** with a relevant answer
5. **Continue the conversation** or say "goodbye" to end

**First call not working?** Wait 2-3 minutes after deployment for all services to initialize, then try again.

---

## Post-Deployment: What You Can Do

### View Call Recordings

```bash
# List recent recordings
aws s3 ls s3://va-dev-recordings-$(terraform -chdir=terraform output -raw random_suffix)/ --recursive
```

### View the Monitoring Dashboard

1. Go to [AWS CloudWatch Console](https://console.aws.amazon.com/cloudwatch/)
2. Click **Dashboards** in the left sidebar
3. Click on **va-dev-voice-agent**

### Check Lambda Logs

```bash
# View recent logs from the orchestrator function
aws logs tail /aws/lambda/va-dev-orchestrator --follow
```

### View Transcripts

```bash
# List recent transcripts
aws s3 ls s3://va-dev-transcripts-$(terraform -chdir=terraform output -raw random_suffix)/ --recursive
```

---

## Customizing Your Voice Agent

### Change What the Agent Says

Edit the system prompt to change the agent's personality and behavior:

```bash
nano bedrock/prompts/voice_agent_system_prompt.txt
```

After editing, redeploy:
```bash
./scripts/deploy.sh dev
```

### Change the Greeting

Edit `config/dev.yaml`:

```yaml
agent:
  greeting_message: "Hi there! Welcome to Acme Corp. What can I do for you?"
```

Then redeploy:
```bash
./scripts/deploy.sh dev
```

### Add Custom Tools (Actions the Agent Can Take)

Edit `bedrock/tools/tool_definitions.json` to add new capabilities like:
- Looking up order status
- Scheduling appointments
- Transferring to specific departments

---

## Destroying the Deployment

**Warning:** This will delete ALL resources including call recordings and transcripts.

**To completely remove everything:**

```bash
./scripts/deploy.sh dev --destroy
```

**You will be asked to confirm:**
```
WARNING: This will destroy all resources in dev
Are you sure you want to destroy? Type 'destroy' to confirm:
```

**Type `destroy` and press Enter.**

---

## Troubleshooting

### "Error: Invalid AWS credentials"

**Problem:** AWS CLI is not configured correctly.

**Solution:**
```bash
aws configure
# Enter your Access Key ID, Secret Access Key, and region
```

### "Error: Amazon Connect instance alias already exists"

**Problem:** Someone else (or a previous deployment) already used this name.

**Solution:** Edit `config/dev.yaml` and change `instance_alias` to something unique:
```yaml
connect:
  instance_alias: my-unique-company-name-dev
```

### "The phone number is not answering"

**Possible causes:**
1. **Wait 2-3 minutes** after deployment for services to initialize
2. **Check CloudWatch logs** for errors:
   ```bash
   aws logs tail /aws/lambda/va-dev-orchestrator --since 5m
   ```
3. **Verify the Lambda function deployed:**
   ```bash
   aws lambda get-function --function-name va-dev-orchestrator
   ```

### "Error: Access Denied when creating resources"

**Problem:** Your AWS user doesn't have enough permissions.

**Solution:** You need administrator access or specific permissions for:
- IAM (to create roles)
- Lambda
- S3
- Amazon Connect
- CloudWatch
- KMS
- VPC

### "Terraform state lock error"

**Problem:** A previous Terraform run didn't complete properly.

**Solution:**
```bash
cd terraform
terraform force-unlock LOCK_ID
```

(Replace `LOCK_ID` with the ID shown in the error message)

---

## Cost Estimate

Running this voice agent costs approximately:

| Component | Cost | Notes |
|-----------|------|-------|
| Amazon Connect | $0.018/minute | Only when calls are active |
| Transcribe | $0.024/minute | Only when calls are active |
| Bedrock (Claude) | ~$0.003/turn | Per conversation turn |
| Polly | $0.016/1M chars | Very low cost |
| Lambda | ~$0.20/million calls | Negligible |
| S3 Storage | ~$0.023/GB/month | For recordings |
| **Idle Cost** | **~$0/day** | No calls = minimal cost |
| **Per Call (3 min avg)** | **~$0.15** | Approximate |

**To minimize costs during testing:**
- Use the `dev` configuration (smaller resources)
- Delete the deployment when not in use: `./scripts/deploy.sh dev --destroy`

---

## Project Structure

```
aws-voice-agent/
│
├── config/                    # Environment configurations
│   ├── dev.yaml              # Development settings ← START HERE
│   └── prod.yaml             # Production settings
│
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   ├── terraform.tfvars.example  # Template for configuration ← COPY THIS
│   └── modules/              # Reusable infrastructure modules
│       ├── connect/          # Amazon Connect setup
│       ├── lambda/           # Lambda functions
│       ├── bedrock/          # AI/ML configuration
│       ├── s3/               # Storage buckets
│       ├── vpc/              # Network configuration
│       ├── iam/              # Security roles
│       ├── kms/              # Encryption keys
│       ├── cloudwatch/       # Monitoring
│       ├── alerting/         # SNS alerts & alarms
│       ├── security/         # GuardDuty, Security Hub, Config
│       ├── secrets/          # Secrets Manager
│       └── backup/           # AWS Backup
│
├── lambda/                    # Application code
│   ├── orchestrator/         # Main voice agent logic
│   │   ├── handler.py        # Entry point
│   │   ├── bedrock_client.py # Claude AI integration
│   │   └── session_manager.py# Conversation state
│   └── integrations/         # External API connectors
│
├── bedrock/                   # AI configuration
│   ├── prompts/              # What the agent says/does
│   │   └── voice_agent_system_prompt.txt  ← CUSTOMIZE THIS
│   ├── guardrails/           # Safety filters
│   └── tools/                # Agent capabilities
│       └── tool_definitions.json  ← ADD CUSTOM ACTIONS
│
├── connect/                   # Phone system configuration
│   └── contact-flows/        # Call routing logic
│
└── scripts/                   # Deployment automation
    ├── setup.sh              # Initial setup
    └── deploy.sh             # Deploy/destroy infrastructure
```

---

## Getting Help

1. **Check the logs first:**
   ```bash
   aws logs tail /aws/lambda/va-dev-orchestrator --since 10m
   ```

2. **Review CloudWatch dashboard** for errors and metrics

3. **Open an issue** on GitHub with:
   - The exact error message
   - Which step you were on
   - Your AWS region
   - Output of `terraform --version` and `aws --version`

---

## Quick Reference

### Interactive Deployment (Recommended)

| Action | Command |
|--------|---------|
| Deploy (guided) | `./deploy.sh` |
| Destroy | `./destroy.sh` |
| View logs | `aws logs tail /aws/lambda/voice-agent-dev-orchestrator --follow` |
| Check status | `cd terraform && terraform output` |

### Config-Based Deployment

| Action | Command |
|--------|---------|
| Initial setup | `./scripts/setup.sh dev` |
| Deploy | `./scripts/deploy.sh dev` |
| Deploy without prompts | `./scripts/deploy.sh dev --auto-approve` |
| Destroy everything | `./scripts/deploy.sh dev --destroy` |
| View logs | `aws logs tail /aws/lambda/va-dev-orchestrator --follow` |
| Check deployment status | `cd terraform && terraform output` |

---

**You're ready to deploy!** Start with [Step 1: Clone the Repository](#step-1-clone-the-repository).
