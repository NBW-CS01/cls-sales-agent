# Jamie 2.0 - Local Usage Guide

## Prerequisites

### Required Software
1. **Python 3.12+**
   ```bash
   python3 --version
   ```

2. **AWS CLI**
   ```bash
   aws --version
   ```

3. **boto3 Python Library**
   ```bash
   pip3 install boto3
   ```

### AWS Configuration
Ensure your AWS credentials are configured:
```bash
# Option 1: AWS SSO (recommended)
aws sso login --profile AdministratorAccess-380414079195

# Option 2: Check if already configured
aws sts get-caller-identity --profile AdministratorAccess-380414079195
```

## Using Jamie CLI

### Installation
```bash
cd /Users/nick.barton-wells/Projects/jamie2.0
chmod +x jamie-cli.py
```

### Usage Examples

#### 1. Direct Prompt (Quick)
```bash
python3 jamie-cli.py "Create a proposal for TechCorp needing AWS migration"
```

#### 2. From Requirements File
```bash
# Create a requirements file
cat > requirements.txt << EOF
Customer: GlobalBank
Project: Cloud Security Assessment
Requirements:
- Multi-cloud environment (AWS + Azure)
- PCI-DSS compliance requirements
- 500+ servers to assess
- Timeline: 3 months
EOF

# Generate proposal
python3 jamie-cli.py --file requirements.txt --output globalbank-proposal.txt
```

#### 3. Interactive Mode (Best for Multiple Proposals)
```bash
python3 jamie-cli.py --interactive

# Then interact:
 You: Create a proposal for a retail company needing e-commerce platform
 Jamie: [generates proposal]

 You: save
 Filename: retail-ecommerce.txt

 You: Now create one for manufacturing IoT implementation
 Jamie: [generates another proposal]

 You: exit
```

#### 4. Quiet Mode (Just Output)
```bash
python3 jamie-cli.py "Create proposal for FinTech startup" --quiet > output.txt
```

## Example Prompts

### Cloud Migration
```bash
python3 jamie-cli.py "Create a comprehensive proposal for Acme Corp's migration of 200 applications from on-premises to AWS. They're in financial services, need PCI compliance, and have a $2M budget."
```

### DevOps Transformation
```bash
python3 jamie-cli.py --file - << EOF
I need a proposal for RetailCo's DevOps transformation:
- Company: RetailCo (e-commerce, 50 developers)
- Current state: Manual deployments, no CI/CD
- Goals: Automated pipelines, infrastructure as code, monitoring
- Timeline: 6 months
- Budget: $150k
EOF
```

### Document Processing (Like Swagger)
```bash
python3 jamie-cli.py "Generate proposal for legal firm needing intelligent document processing. They have 500TB of contracts to classify, extract metadata, and deduplicate."
```

## Configuration

Edit `jamie-cli.py` if you need to change:

```python
# Line 13-16
AWS_PROFILE = 'AdministratorAccess-380414079195'  # Your AWS profile
AWS_REGION = 'eu-west-2'                          # Your region
AGENT_ID = 'LUZWQYYBP4'                          # Jamie's agent ID
AGENT_ALIAS_ID = '65PC3XRFMX'                    # Agent alias
```

## Tips for Best Results

### 1. Be Specific
 Bad: "Create a proposal"
 Good: "Create a proposal for HealthTech Inc, a healthcare company with 200 employees needing HIPAA-compliant cloud migration of their patient management system"

### 2. Provide Context
Include:
- Customer name and industry
- Problem/challenge they're facing
- Technical requirements
- Budget range (if known)
- Timeline
- Compliance needs

### 3. Use Jamie's Knowledge Base
Jamie has access to proposals in S3. Mention similar projects:
```bash
python3 jamie-cli.py "Create a proposal similar to the Edwin Group project, but for manufacturing company needing real-time data processing"
```

### 4. Iterate
If first result isn't perfect:
```bash
python3 jamie-cli.py --interactive

 You: Create proposal for cloud migration
 Jamie: [generates proposal]

 You: Make it more technical and add a detailed security section
 Jamie: [refines proposal]
```

## Troubleshooting

### Error: "Profile not found"
```bash
# Login to AWS SSO
aws sso login --profile AdministratorAccess-380414079195
```

### Error: "boto3 not found"
```bash
pip3 install boto3
```

### Error: "Agent validation exception"
Check if Claude 3.7 Sonnet is enabled:
- AWS Console → Bedrock → Model access
- Verify "Claude 3.7 Sonnet" is enabled

### Slow Response
- First request may take 30-60 seconds
- Subsequent requests are faster
- Complex proposals take 1-2 minutes

## Advanced Usage

### Batch Processing
```bash
# Create multiple proposals
for customer in acme globex initech; do
  python3 jamie-cli.py "Create proposal for $customer" \
    --output "${customer}-proposal.txt"
done
```

### Custom Wrapper Script
```bash
#!/bin/bash
# quick-proposal.sh

echo "Customer name:"
read customer

echo "Project type:"
read project

python3 /Users/nick.barton-wells/Projects/jamie2.0/jamie-cli.py \
  "Create a professional proposal for $customer regarding $project" \
  --output "${customer}-${project}-$(date +%Y%m%d).txt"

echo " Proposal saved!"
```

## Next Steps

1. **Upload More Proposals**: Add Jamie's past proposals to S3
   ```bash
   aws s3 cp proposal.pdf s3://jamie2-knowledge-base-0t76l52f/proposals/ \
     --profile AdministratorAccess-380414079195
   ```

2. **Complete Jamie's Persona**: Edit `jamie-persona.md` with Jamie's writing style

3. **Create Templates**: Save common prompts as files

4. **Share with Team**: Give Patrick and Sharona access to the CLI

## Help

```bash
python3 jamie-cli.py --help
```

For issues, check:
- `/aws/lambda/jamie2-document-retriever` CloudWatch logs
- AWS Bedrock console for agent status
