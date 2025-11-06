# NDA Generation Feature - Deployment & Usage Guide

## Overview

Jamie 2.0 now includes automated NDA generation using:
- **Companies House API**: Fetches company information automatically
- **NDA Template**: Populates Word document with company and signatory details
- **Bedrock Agent**: Natural language interface for generating NDAs

## Features

✅ Automatic company data lookup from Companies House
✅ Jurisdiction inference (England & Wales, Scotland, Northern Ireland)
✅ Company type detection from registration number prefix
✅ Word document generation with populated fields
✅ S3 storage with presigned download URLs
✅ Natural language interface via Bedrock Agent

---

## Prerequisites

### 1. Companies House API Key (Optional but Recommended)

Get a free API key from Companies House:
1. Visit: https://developer.company-information.service.gov.uk/
2. Create an account
3. Generate an API key
4. Keep it secure (will be added to Terraform)

**Note**: API works without key but has rate limits.

### 2. NDA Template

Ensure the NDA template is uploaded to S3:
- **Location**: `templates/Non-Disclosure Agreement Template v01 JC OFFLINE.docx`
- **Required fields** (these will be auto-populated):
  - `[Company Name]`
  - `[Company Number]`
  - `[Company Type]`
  - `[Registered Office Address]`
  - `[Jurisdiction]`
  - `[Signatory Name]`
  - `[Signatory Title]`
  - `[Date]`

---

## Deployment Steps

### Step 1: Install Lambda Dependencies

```bash
cd /Users/nick.barton-wells/Projects/cls-sales-agent/lambda

# Create a package directory
mkdir -p package

# Install python-docx and dependencies
pip install -r requirements.txt -t package/

# Copy Lambda functions
cp companies_house.py package/
cp nda_generator.py package/
```

### Step 2: Upload NDA Template to S3

```bash
# Get the S3 bucket name from Terraform
cd /Users/nick.barton-wells/Projects/cls-sales-agent/terraform
BUCKET=$(terraform output -raw knowledge_base_bucket)

# Upload the NDA template
aws s3 cp \
  /Users/nick.barton-wells/Projects/cls-sales-agent/templates/"Non-Disclosure Agreement Template v01 JC OFFLINE.docx" \
  s3://${BUCKET}/templates/ \
  --profile AdministratorAccess-380414079195
```

### Step 3: Deploy Infrastructure

```bash
cd /Users/nick.barton-wells/Projects/cls-sales-agent/terraform

# Initialize Terraform (if not already done)
terraform init

# Optional: Set Companies House API key
export TF_VAR_companies_house_api_key="your-api-key-here"

# Deploy
terraform apply \
  -var="aws_profile=AdministratorAccess-380414079195"
```

### Step 4: Prepare and Update Agent

After deployment, you need to prepare the agent to activate the new action group:

```bash
# Get the agent ID
AGENT_ID=$(terraform output -raw bedrock_agent_id)

# Prepare the agent (activates new action groups)
aws bedrock-agent prepare-agent \
  --agent-id $AGENT_ID \
  --profile AdministratorAccess-380414079195 \
  --region eu-west-2
```

---

## Usage Examples

### Example 1: Generate NDA by Company Number

**Prompt to Jamie 2.0:**
```
Please generate an NDA for company number SC123456.
The signatory is Patrick Godden, Director.
```

**What happens:**
1. Jamie looks up SC123456 on Companies House
2. Extracts: company name, address, type
3. Infers: Jurisdiction = "Scotland" (from SC prefix)
4. Populates NDA template
5. Saves to S3 and returns download link

### Example 2: Generate NDA by Company Name

**Prompt to Jamie 2.0:**
```
I need an NDA for Acme Financial Services Limited.
Signatory: Sharona Rollnick, Managing Partner.
```

**What happens:**
1. Jamie searches Companies House for "Acme Financial Services Limited"
2. Finds matching company and gets registration details
3. Generates NDA with populated fields
4. Returns presigned download URL (valid 1 hour)

### Example 3: Scottish Company

**Prompt:**
```
Generate NDA for company SC987654, signed by Jamie Collingwood, CEO
```

**Output includes:**
- Company details from Companies House
- Jurisdiction: "Scotland" (inferred from SC prefix)
- Company Type: "Private Limited Company" (inferred from SC prefix)
- Populated NDA document

---

## Company Number Prefixes Reference

The system automatically infers jurisdiction and type from company number prefixes:

### England and Wales (default)
- `01234567` - Private Limited Company
- `OC123456` - Limited Liability Partnership
- `LP123456` - Limited Partnership
- `FC123456` - Overseas Company

### Scotland
- `SC123456` - Private Limited Company (Scotland)
- `SO123456` - Limited Liability Partnership (Scotland)
- `SL123456` - Limited Partnership (Scotland)

### Northern Ireland
- `NI123456` - Private Limited Company (Northern Ireland)
- `NC123456` - Limited Liability Partnership (Northern Ireland)
- `NL123456` - Limited Partnership (Northern Ireland)

See `companies_house.py` for complete prefix mappings.

---

## Testing

### Test 1: Validate Companies House Integration

```bash
cd /Users/nick.barton-wells/Projects/cls-sales-agent/lambda
python companies_house.py
```

Expected: Successfully fetches test company data

### Test 2: Test Lambda Locally

```bash
cd /Users/nick.barton-wells/Projects/cls-sales-agent/lambda

# Set environment variables
export KNOWLEDGE_BASE_BUCKET="jamie2-knowledge-base-xxxxx"
export COMPANIES_HOUSE_API_KEY="your-key-here"

# Run test
python nda_generator.py
```

### Test 3: Test via AWS Console

1. Go to Lambda console
2. Open `jamie2-nda-generator`
3. Configure test event:
```json
{
  "actionGroup": "NDAGeneration",
  "function": "generateNDA",
  "parameters": [
    {"name": "company_identifier", "value": "01234567"},
    {"name": "signatory_name", "value": "Patrick Godden"},
    {"name": "signatory_title", "value": "Director"}
  ],
  "messageVersion": "1.0"
}
```
4. Run test
5. Check CloudWatch logs for output

### Test 4: Test via Bedrock Agent

Use the Bedrock Agent console or jamie-cli.py:
```
Generate an NDA for company 01234567, signatory Patrick Godden, Director
```

---

## Generated NDA Storage

Generated NDAs are saved to:
```
s3://jamie2-knowledge-base-xxxxx/generated-ndas/
├── NDA_Company_Name_20251106-143022.docx
├── NDA_Another_Company_20251106-150145.docx
└── ...
```

### S3 Metadata

Each generated NDA includes metadata:
- `company_name`: Full company name
- `company_number`: Companies House number
- `signatory_name`: Name of signatory
- `signatory_title`: Title of signatory
- `generated_date`: Timestamp (YYYYMMDD-HHMMSS)

---

## Troubleshooting

### Issue: "Company not found"

**Causes:**
- Invalid company number
- Company dissolved/inactive
- Typo in company name

**Solutions:**
- Verify company number on Companies House website
- Search by name first to get correct number
- Check company status (must be "active")

### Issue: "Template not found"

**Cause**: NDA template not uploaded to S3

**Solution:**
```bash
BUCKET=$(cd terraform && terraform output -raw knowledge_base_bucket)
aws s3 cp templates/"Non-Disclosure Agreement Template v01 JC OFFLINE.docx" \
  s3://${BUCKET}/templates/ \
  --profile AdministratorAccess-380414079195
```

### Issue: Lambda timeout

**Cause**: Complex document or slow API response

**Solution**: Increase Lambda timeout in `terraform/main.tf`:
```hcl
timeout = 180  # Increase from 120 to 180 seconds
```

### Issue: "python-docx not found"

**Cause**: Lambda layer not properly packaged

**Solution**: Rebuild Lambda package with dependencies:
```bash
cd lambda
rm -rf package
mkdir package
pip install -r requirements.txt -t package/
cp *.py package/
cd package && zip -r ../nda_generator.zip . && cd ..
```

---

## Monitoring

### CloudWatch Logs

View logs in CloudWatch:
```
/aws/lambda/jamie2-nda-generator
```

### Key Metrics to Monitor

1. **Invocation Count**: How many NDAs generated
2. **Error Rate**: Failed generations
3. **Duration**: Time to generate (should be < 30s)
4. **Companies House API Calls**: Rate limit usage

### Sample Log Analysis

```bash
# View recent NDA generation logs
aws logs tail /aws/lambda/jamie2-nda-generator \
  --follow \
  --profile AdministratorAccess-380414079195 \
  --region eu-west-2
```

---

## Cost Estimate

### Per NDA Generation

- **Lambda Execution**: $0.0001 (1 sec @ 1024MB)
- **Companies House API**: Free (with API key)
- **S3 Storage**: $0.000025 per NDA stored
- **Bedrock Agent**: $0.003 per request

**Total per NDA**: ~$0.003 (less than 1p)

### Monthly (100 NDAs)

- Lambda: $0.01
- S3: $0.0025
- Bedrock: $0.30

**Total**: ~$0.31/month for 100 NDAs

---

## Security Considerations

### API Key Protection

✅ Stored as Terraform variable (sensitive)
✅ Passed via environment variable to Lambda
✅ Not logged or exposed in responses

### Generated NDAs

✅ Stored in private S3 bucket
✅ Presigned URLs expire after 1 hour
✅ Access logged in CloudWatch
✅ Encryption at rest (AES256)

### Companies House Data

✅ Public information only (no sensitive data)
✅ Read-only API access
✅ Rate-limited to prevent abuse

---

## Integration with Workflow

### Patrick/Sharona Workflow

1. **Receive NDA Request** from customer
2. **Ask Jamie 2.0**: "Generate NDA for [Company Name], signed by [Name], [Title]"
3. **Jamie responds** with:
   - Company details confirmed
   - Download link to populated NDA
4. **Review NDA** (download from link)
5. **Send to customer** for signature

### Jamie Collingwood Review

- Jamie C. can review generated NDAs in S3
- S3 bucket: `s3://jamie2-knowledge-base-xxxxx/generated-ndas/`
- Download and check formatting/accuracy
- Provide feedback for template improvements

---

## Future Enhancements

### Planned Features

- [ ] Digital signature integration (DocuSign API)
- [ ] Email delivery to customer
- [ ] NDA version tracking
- [ ] Bulk NDA generation (multiple companies)
- [ ] Custom NDA clauses (e.g., IP assignment, term duration)
- [ ] Integration with CRM (Salesforce/HubSpot)

### Feedback Welcome

Users: Patrick Godden, Sharona Rollnick
Reviewer: Jamie Collingwood

Please report issues or suggestions to improve the NDA generation process.

---

## Quick Reference Card

### Generate NDA (Natural Language)

```
"Generate an NDA for [Company Name/Number]"
"Signatory: [Name], [Title]"
```

### Check Generated NDAs

```bash
BUCKET=$(cd terraform && terraform output -raw knowledge_base_bucket)
aws s3 ls s3://${BUCKET}/generated-ndas/ --profile AdministratorAccess-380414079195
```

### Download NDA

```bash
aws s3 cp s3://${BUCKET}/generated-ndas/NDA_Company_Name_DATE.docx . \
  --profile AdministratorAccess-380414079195
```

---

**Documentation Last Updated**: 2025-11-06
**Jamie 2.0 Version**: 2.0 (with NDA Generation)
