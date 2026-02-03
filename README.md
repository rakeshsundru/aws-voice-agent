# AWS Voice Agent

A production-grade, AWS-native voice agent system built with Amazon Connect, Bedrock (Claude), Transcribe, Polly, and Neptune.

## Overview

This project provides a complete, end-to-end voice agent solution that can be deployed to any AWS environment via configuration. It replaces traditional IVR systems with an AI-powered conversational agent that can handle natural language interactions over the phone.

### Key Features

- **Natural Conversation**: Powered by Claude 3.5 Sonnet via Amazon Bedrock for intelligent, context-aware responses
- **Real-time Processing**: Sub-2-second latency for natural conversation flow
- **Memory & Context**: Neptune graph database for conversation history and caller profiles
- **Security-First**: HIPAA-ready architecture with encryption, PII redaction, and audit trails
- **Fully Configurable**: Deploy to any environment by updating a single config file
- **Production-Ready**: Comprehensive monitoring, alerting, and error handling

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Amazon Connect                               │
│                    (Telephony + Contact Flows)                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Lambda Orchestrator                             │
│              (Session Management + Business Logic)                   │
└──────┬─────────────────────┼─────────────────────┬──────────────────┘
       │                     │                     │
       ▼                     ▼                     ▼
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│  Transcribe │     │     Bedrock     │     │    Polly    │
│   (STT)     │     │ (Claude 3.5)   │     │    (TTS)    │
└─────────────┘     └─────────────────┘     └─────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │    Neptune      │
                    │ (Graph Memory)  │
                    └─────────────────┘
```

## Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Terraform >= 1.5
- Python 3.11+
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/aws-voice-agent.git
   cd aws-voice-agent
   ```

2. **Run initial setup**
   ```bash
   ./scripts/setup.sh dev
   ```

3. **Review and customize configuration**
   ```bash
   vim config/dev.yaml
   ```

4. **Deploy**
   ```bash
   ./scripts/deploy.sh dev
   ```

5. **Test with a phone call**
   - Call the phone number shown in the deployment output
   - Speak naturally and interact with the agent

## Project Structure

```
aws-voice-agent/
├── terraform/                 # Infrastructure as Code
│   ├── modules/               # Reusable Terraform modules
│   │   ├── connect/           # Amazon Connect
│   │   ├── bedrock/           # Bedrock + Guardrails
│   │   ├── lambda/            # Lambda functions
│   │   ├── neptune/           # Graph database
│   │   ├── s3/                # Storage buckets
│   │   ├── cloudwatch/        # Monitoring
│   │   ├── iam/               # IAM roles/policies
│   │   ├── kms/               # Encryption keys
│   │   └── vpc/               # Network infrastructure
│   ├── environments/          # Environment-specific configs
│   ├── main.tf                # Root module
│   ├── variables.tf           # Input variables
│   └── outputs.tf             # Output values
├── lambda/                    # Lambda function code
│   ├── orchestrator/          # Main orchestration logic
│   ├── integrations/          # External API connectors
│   └── utils/                 # Shared utilities
├── bedrock/                   # Bedrock configuration
│   ├── prompts/               # System prompts
│   ├── guardrails/            # Safety configurations
│   └── tools/                 # Tool definitions
├── connect/                   # Connect configuration
│   └── contact-flows/         # Contact flow definitions
├── neptune/                   # Graph database schema
│   ├── schema/                # Vertex/edge definitions
│   └── queries/               # Common Gremlin queries
├── monitoring/                # CloudWatch dashboards/alarms
├── config/                    # Environment configurations
├── scripts/                   # Deployment scripts
├── tests/                     # Test suites
└── docs/                      # Documentation
```

## Configuration

The system is fully configuration-driven. Each environment has a YAML config file:

```yaml
environment: prod
aws_region: us-east-1
project_name: voice-agent

bedrock:
  model_id: anthropic.claude-3-5-sonnet-20241022-v2:0
  max_tokens: 2000
  guardrails_enabled: true

connect:
  instance_alias: voice-agent-prod
  claim_phone_number: true
  phone_number_type: TOLL_FREE

neptune:
  enabled: true
  instance_class: db.r5.large

agent:
  company_name: "ACME Corporation"
  greeting_message: "Hello! How can I help you today?"
```

See `config/dev.yaml` for a complete example.

## Deployment

### Deploy to Development
```bash
./scripts/deploy.sh dev
```

### Deploy to Production
```bash
./scripts/deploy.sh prod --auto-approve
```

### Destroy Environment
```bash
./scripts/deploy.sh dev --destroy
```

## Monitoring

The deployment creates a CloudWatch dashboard with:
- Lambda invocations and errors
- Bedrock latency and token usage
- Connect call metrics
- End-to-end latency tracking

Access the dashboard at:
```
https://<region>.console.aws.amazon.com/cloudwatch/home?region=<region>#dashboards:name=<prefix>-voice-agent
```

## Security

This system is designed with HIPAA compliance in mind:

- **Encryption at Rest**: All data encrypted with KMS (S3, Neptune, CloudWatch Logs)
- **Encryption in Transit**: TLS 1.2+ for all communications
- **PII Redaction**: Automatic redaction of sensitive information
- **Audit Logging**: CloudTrail enabled for all API calls
- **Least Privilege**: Fine-grained IAM roles for each service
- **Network Isolation**: VPC with private subnets and VPC endpoints

## Customization

### Adding New Tools

1. Define the tool in `bedrock/tools/tool_definitions.json`
2. Implement the handler in `lambda/orchestrator/handler.py`
3. Test the integration
4. Deploy

### Modifying Prompts

Edit the prompts in `bedrock/prompts/`:
- `voice_agent_system_prompt.txt` - Main agent behavior
- `greeting_prompt.txt` - Initial greeting
- `fallback_prompt.txt` - Error handling

### Adding Integrations

1. Create a connector in `lambda/integrations/`
2. Add the API configuration to your environment config
3. Deploy the changes

## Testing

```bash
# Run unit tests
pytest tests/unit/

# Run integration tests
pytest tests/integration/

# Run load tests
./tests/load/run_load_test.sh
```

## Cost Optimization

Estimated costs per 1,000 calls (assuming 3-minute average duration):

| Service | Estimated Cost |
|---------|---------------|
| Connect | $0.018/min |
| Transcribe | $0.024/min |
| Bedrock (Claude) | ~$0.03/call |
| Polly | $0.016/1M chars |
| Neptune | $0.10/hour (always on) |
| **Total** | ~$0.15/call |

Tips to reduce costs:
- Use provisioned concurrency only in production
- Enable Neptune only when memory features are needed
- Use Glacier for long-term recording storage
- Monitor and optimize prompt token usage

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and solutions.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and feature requests, please use the GitHub issue tracker.
