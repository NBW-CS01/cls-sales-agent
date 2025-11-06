# Jamie 2.0 - Deployment Checklist

## ⚠️ CRITICAL: Account Verification

**Jamie 2.0 MUST ONLY be deployed to AWS Account: `380414079195`**

### Pre-Deployment Verification

```bash
# Verify you're using the correct AWS profile
aws sts get-caller-identity --profile AdministratorAccess-380414079195

# Expected output:
# {
#     "UserId": "...",
#     "Account": "380414079195",  ← MUST be this
#     "Arn": "arn:aws:sts::380414079195:..."
# }
```

**If the Account ID is NOT `380414079195`, STOP immediately!**

---

## Security Safeguards

### Terraform Protections

We've implemented multiple safeguards:

1. **Provider-level restriction**:
```hcl
provider "aws" {
  allowed_account_ids = ["380414079195"]  # ← Terraform will fail if wrong account
}
```

2. **Runtime validation**:
```hcl
locals {
  validate_account = (
    local.current_account_id == "380414079195"
    ? local.current_account_id
    : file("ERROR: Wrong account!")  # ← Will fail terraform plan
  )
}
```

3. **Default profile**:
```hcl
variable "aws_profile" {
  default = "AdministratorAccess-380414079195"  # ← Correct profile by default
}
```

### What Happens If You Try Wrong Account?

Terraform will **immediately fail** with:
```
Error: Configuration contains invalid values

Provider configuration for registry.terraform.io/hashicorp/aws
account ID not allowed for provider
```

---

## Deployment Steps

### 1. Pre-Deployment Checks

```bash
cd /Users/nick.barton-wells/Projects/cls-sales-agent

# ✓ Verify AWS account
aws sts get-caller-identity --profile AdministratorAccess-380414079195 | grep "380414079195"

# ✓ Check Terraform is installed
terraform version

# ✓ Verify files are present
ls -la lambda/
ls -la templates/
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

**Expected output:**
```
Terraform has been successfully initialized!
```

### 3. Plan Deployment

```bash
terraform plan -var="aws_profile=AdministratorAccess-380414079195"
```

**What to check:**
- First line of output shows: `data.aws_caller_identity.current: Reading...`
- Look for account ID `380414079195` in ARNs
- Review resources to be created (~40 resources)

**Red flags:**
- Different account ID appears
- Error about "account not allowed"
- Missing resources

### 4. Apply Deployment

```bash
terraform apply -var="aws_profile=AdministratorAccess-380414079195"
```

**Confirmation prompt:**
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes  ← Type 'yes' and press Enter
```

**Expected duration:** 3-5 minutes

### 5. Verify Deployment

```bash
# Check outputs
terraform output

# Verify account (MUST show 380414079195)
terraform output aws_account_id

# Get S3 bucket name
terraform output knowledge_base_bucket

# Get agent ID
terraform output agent_id
```

**Expected output:**
```
aws_account_id = "380414079195"
deployment_verification = "✓ Deployed to account 380414079195 in eu-west-2"
knowledge_base_bucket = "jamie2-knowledge-base-xxxxx"
...
```

---

## Post-Deployment Tasks

### 1. Upload NDA Template

```bash
# Get bucket name
BUCKET=$(cd terraform && terraform output -raw knowledge_base_bucket)

# Upload template
aws s3 cp \
  templates/"Non-Disclosure Agreement Template v01 JC OFFLINE.docx" \
  s3://${BUCKET}/templates/ \
  --profile AdministratorAccess-380414079195

# Verify upload
aws s3 ls s3://${BUCKET}/templates/ --profile AdministratorAccess-380414079195
```

### 2. Upload Knowledge Base Documents

```bash
# Upload NDAs
aws s3 sync knowledge/NDAs/ s3://${BUCKET}/knowledge/NDAs/ \
  --profile AdministratorAccess-380414079195

# Upload MSAs
aws s3 sync knowledge/MSAs/ s3://${BUCKET}/knowledge/MSAs/ \
  --profile AdministratorAccess-380414079195

# Upload SOWs
aws s3 sync knowledge/SOWs/ s3://${BUCKET}/knowledge/SOWs/ \
  --profile AdministratorAccess-380414079195

# Verify uploads
aws s3 ls s3://${BUCKET}/knowledge/ --recursive --profile AdministratorAccess-380414079195
```

### 3. Generate Vector Embeddings

```bash
# Run embedding script
./embed-documents.py \
  --bucket ${BUCKET} \
  --profile AdministratorAccess-380414079195

# This will:
# - Process all documents in knowledge/, proposals/, sows/
# - Generate vector embeddings
# - Store in vectors/ folder
# - Takes ~30 seconds per document
```

### 4. Prepare Bedrock Agent

```bash
# Get agent ID
AGENT_ID=$(cd terraform && terraform output -raw agent_id)

# Prepare agent (activates new action groups)
aws bedrock-agent prepare-agent \
  --agent-id $AGENT_ID \
  --profile AdministratorAccess-380414079195 \
  --region eu-west-2

# Wait for preparation (takes ~30 seconds)
aws bedrock-agent get-agent \
  --agent-id $AGENT_ID \
  --profile AdministratorAccess-380414079195 \
  --region eu-west-2 \
  --query 'agent.agentStatus'
```

**Expected status:** `PREPARED`

### 5. Test NDA Generation

```bash
# Test via jamie-cli.py or AWS console
python jamie-cli.py

# Try: "Generate an NDA for company 01234567, signatory Patrick Godden, Director"
```

---

## Security Verification

### Check Encryption

```bash
BUCKET=$(cd terraform && terraform output -raw knowledge_base_bucket)

# Verify KMS encryption is enabled
aws s3api get-bucket-encryption \
  --bucket $BUCKET \
  --profile AdministratorAccess-380414079195

# Expected: Shows aws:kms algorithm
```

### Check Public Access Block

```bash
# Verify public access is blocked
aws s3api get-public-access-block \
  --bucket $BUCKET \
  --profile AdministratorAccess-380414079195

# Expected: All four settings = true
```

### Check Access Logging

```bash
# Verify access logging is enabled
aws s3api get-bucket-logging \
  --bucket $BUCKET \
  --profile AdministratorAccess-380414079195

# Expected: Shows target bucket for logs
```

---

## Rollback Procedure

If something goes wrong:

```bash
cd terraform

# Destroy all resources
terraform destroy -var="aws_profile=AdministratorAccess-380414079195"

# Type 'yes' to confirm
```

**Warning:** This will delete:
- All Lambda functions
- S3 buckets (if empty)
- Bedrock agent
- IAM roles
- KMS keys (with 30-day recovery)

**Data safety:**
- S3 versioning protects against accidental deletion
- KMS keys have 30-day deletion window
- Access logs retained

---

## Troubleshooting

### Error: "Account not allowed"

**Problem:** Trying to deploy to wrong AWS account

**Solution:**
```bash
# Check current account
aws sts get-caller-identity

# If wrong account, use correct profile:
export AWS_PROFILE=AdministratorAccess-380414079195

# Re-run terraform
terraform plan
```

### Error: "Failed to upload template"

**Problem:** S3 bucket doesn't exist or wrong permissions

**Solution:**
```bash
# Verify bucket exists
aws s3 ls --profile AdministratorAccess-380414079195 | grep jamie2-knowledge-base

# Check IAM permissions
aws sts get-caller-identity --profile AdministratorAccess-380414079195
```

### Error: "Lambda function timeout"

**Problem:** Lambda taking too long (>120s for NDA generation)

**Solution:**
```bash
# Increase timeout in terraform/main.tf:
# timeout = 180  # Increase from 120 to 180

# Re-apply
terraform apply
```

### Warning: "Generated NDAs not found"

**Problem:** NDA template not uploaded

**Solution:**
```bash
BUCKET=$(cd terraform && terraform output -raw knowledge_base_bucket)

aws s3 ls s3://${BUCKET}/templates/

# If empty, re-upload template (see step 1 above)
```

---

## Cost Monitoring

### Expected Monthly Costs

**Base infrastructure:**
- Lambda execution: $0.10
- S3 storage (10GB): $0.23
- KMS key: $1.00
- S3 access logs: $0.02
- **Total: ~$1.35/month**

**Per-use costs:**
- Bedrock Claude invocations: $0.003/request
- Titan embeddings: $0.0001/embedding
- **100 NDAs/month: ~$0.35**

**Total expected: ~$1.70/month**

### Monitor Costs

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -v1d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://<(echo '{
    "Dimensions": {
      "Key": "SERVICE",
      "Values": ["Amazon Simple Storage Service", "AWS Lambda", "Amazon Bedrock"]
    }
  }') \
  --profile AdministratorAccess-380414079195
```

---

## Maintenance Schedule

### Weekly

- [ ] Review CloudWatch logs for errors
- [ ] Check S3 access logs for unusual activity
- [ ] Monitor Lambda invocation counts

### Monthly

- [ ] Review AWS costs (should be <$2/month)
- [ ] Check KMS key rotation status
- [ ] Audit IAM permissions
- [ ] Clean up old generated NDAs (if needed)

### Quarterly

- [ ] Review and update NDA templates
- [ ] Re-generate vector embeddings for new documents
- [ ] Security audit (check SECURITY.md)
- [ ] Update Terraform provider versions

---

## Emergency Contacts

**AWS Account Owner:** CloudScaler
**Account ID:** 380414079195
**Region:** eu-west-2 (London)

**Jamie 2.0 Users:**
- Patrick Godden (Primary User)
- Sharona Rollnick (Primary User)
- Jamie Collingwood (Reviewer)

**Support:**
- AWS Support: Via AWS Console
- Terraform Issues: GitHub Issues
- Security Concerns: SECURITY.md

---

## Success Criteria

Deployment is successful when:

✅ Terraform output shows account `380414079195`
✅ S3 bucket created with KMS encryption
✅ Access logging enabled
✅ All Lambda functions deployed
✅ Bedrock agent status = `PREPARED`
✅ NDA template uploaded
✅ Vector embeddings generated
✅ Test NDA generation succeeds
✅ No errors in CloudWatch logs
✅ Security controls verified

---

**Last Updated:** 2025-11-06
**Terraform Version:** 1.0+
**AWS Provider Version:** ~> 5.70
