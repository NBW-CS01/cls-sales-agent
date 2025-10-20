# Jamie 2.0 Deployment Guide

## Architecture Overview

Jamie 2.0 uses a **cost-effective architecture** that avoids expensive vector databases:
- **Bedrock Agent** with Claude 3.5 Sonnet for proposal generation
- **S3 bucket** for storing proposals and SOWs
- **Lambda function** for document search and retrieval
- **No OpenSearch or Pinecone** - keeping costs minimal

## Prerequisites

1. **AWS Account** with access to:
   - Amazon Bedrock (Claude 3.5 Sonnet enabled)
   - S3
   - Lambda
   - IAM

2. **Terraform** installed (v1.0+)

3. **AWS CLI** configured with appropriate profile:
   ```bash
   aws configure --profile AdministratorAccess-380414079195
   ```

4. **Jamie's Writing Samples** - Collect 5-10 representative proposals/SOWs

## Step 1: Capture Jamie's Writing Style

Before deploying, you need to analyze Jamie's writing style:

1. Collect 5-10 of Jamie's best proposals and SOWs
2. Review `jamie-persona.md` and fill in the characteristics:
   - Tone and voice
   - Structure preferences
   - Common phrases
   - Technical depth
   - Formatting style

3. Update `prompts/jamie-system-prompt.txt` with specific examples

## Step 2: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (use main-simple.tf which avoids expensive vector DBs)
terraform apply

# Note the outputs
terraform output
```

## Step 3: Upload Knowledge Base Content

```bash
# Get bucket name from terraform output
BUCKET_NAME=$(terraform output -raw knowledge_base_bucket)

# Create directory structure
aws s3api put-object --bucket ${BUCKET_NAME} --key proposals/by-industry/ --profile AdministratorAccess-380414079195
aws s3api put-object --bucket ${BUCKET_NAME} --key proposals/by-solution/ --profile AdministratorAccess-380414079195
aws s3api put-object --bucket ${BUCKET_NAME} --key sows/ --profile AdministratorAccess-380414079195
aws s3api put-object --bucket ${BUCKET_NAME} --key capabilities/ --profile AdministratorAccess-380414079195
aws s3api put-object --bucket ${BUCKET_NAME} --key case-studies/ --profile AdministratorAccess-380414079195
aws s3api put-object --bucket ${BUCKET_NAME} --key templates/ --profile AdministratorAccess-380414079195

# Upload your proposals and SOWs
aws s3 cp ./your-proposals/ s3://${BUCKET_NAME}/proposals/ --recursive --profile AdministratorAccess-380414079195
aws s3 cp ./your-sows/ s3://${BUCKET_NAME}/sows/ --recursive --profile AdministratorAccess-380414079195

# Upload capability documents
aws s3 cp ./capabilities/ s3://${BUCKET_NAME}/capabilities/ --recursive --profile AdministratorAccess-380414079195
```

## Step 4: Test Jamie 2.0

### Using AWS Console
1. Navigate to Amazon Bedrock > Agents
2. Find "jamie2" agent
3. Test with a sample query:
   ```
   I need to create a proposal for a mid-sized financial services company
   looking to migrate their on-premises infrastructure to AWS. They have
   about 50 applications and are concerned about security and compliance.
   ```

### Using AWS CLI
```bash
AGENT_ID=$(terraform output -raw agent_id)
AGENT_ALIAS_ID=$(terraform output -raw agent_alias_id)

aws bedrock-agent-runtime invoke-agent \
  --agent-id ${AGENT_ID} \
  --agent-alias-id ${AGENT_ALIAS_ID} \
  --session-id "test-session-1" \
  --input-text "Create a proposal for a financial services cloud migration project" \
  --profile AdministratorAccess-380414079195 \
  output.txt

cat output.txt
```

## Step 5: Build Simple UI (Optional)

For Patrick and Sharona to interact easily:

```bash
# Create a simple web interface using API Gateway + Lambda
cd ../ui
# TODO: Create simple HTML/JS interface or Streamlit app
```

## Cost Estimates

**Monthly costs (estimated)**:
- **Bedrock Agent**: ~$0 (pay per use)
- **Claude 3.5 Sonnet API calls**: ~$3-15/month (depends on usage)
- **S3 storage**: ~$0.50/month (for 20GB of proposals)
- **Lambda invocations**: ~$0.20/month (1000 invocations)
- **Total**: ~$5-20/month

**No costs for**:
- OpenSearch Serverless (~$700/month saved!)
- Pinecone (~$70/month saved!)

## Maintenance

### Adding New Proposals
```bash
# Upload new proposal with metadata
aws s3 cp new-proposal.pdf s3://${BUCKET_NAME}/proposals/by-industry/retail/2024-10-15_customer-name_cloud-migration_v1.pdf \
  --metadata industry=retail,solution=cloud-migration,status=won \
  --profile AdministratorAccess-380414079195
```

### Updating Jamie's Style
1. Edit `jamie-persona.md` with new observations
2. Update `prompts/jamie-system-prompt.txt`
3. Redeploy agent:
   ```bash
   cd terraform
   terraform apply
   ```

### Monitoring
```bash
# Check Lambda logs
aws logs tail /aws/lambda/jamie2-document-retriever --follow --profile AdministratorAccess-380414079195

# Check Bedrock Agent usage
aws bedrock-agent list-agent-action-groups --agent-id ${AGENT_ID} --profile AdministratorAccess-380414079195
```

## Troubleshooting

### Agent not finding documents
- Check S3 bucket permissions
- Verify Lambda has correct IAM permissions
- Test Lambda directly with sample query
- Check CloudWatch logs for errors

### Proposals don't sound like Jamie
- Review and refine `jamie-persona.md`
- Add more example proposals to S3
- Update system prompt with specific phrases
- Test with different prompts

### Lambda timeout
- Increase Lambda timeout in terraform (currently 60s)
- Optimize document search algorithm
- Reduce max_results parameter

## Next Steps

1.  Deploy infrastructure
2.  Upload 10+ sample proposals
3.  Complete Jamie persona analysis
4.  Test with real pre-sales scenarios
5. ⏳ Build simple web UI
6. ⏳ Add voice dictation (Amazon Transcribe)
7. ⏳ Integrate with CRM/deal tracking

## Future Enhancements

- **Voice Input**: Amazon Transcribe for Patrick's dictation
- **Multi-language**: Support for international proposals
- **Version Control**: Track proposal iterations
- **Feedback Loop**: Learn from won/lost deals
- **Integration**: Connect with Salesforce/HubSpot
- **Analytics**: Track which proposals perform best
