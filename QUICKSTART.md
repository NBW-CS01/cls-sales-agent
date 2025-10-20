# Jamie 2.0 Quick Start Guide

## What is Jamie 2.0?
An AI assistant that writes sales proposals and SOWs in Jamie's style, helping Patrick, Sharona, and the pre-sales team create winning proposals faster.

## Quick Setup (30 minutes)

### 1. Analyze Jamie's Writing (10 min)
- Collect 5-10 of Jamie's proposals
- Fill out `jamie-persona.md` with his writing characteristics
- Note: This is the most important step!

### 2. Deploy to AWS (10 min)
```bash
cd terraform
terraform init
terraform apply -var="aws_profile=AdministratorAccess-380414079195"
```

### 3. Upload Content (10 min)
```bash
# Get bucket name
BUCKET=$(terraform output -raw knowledge_base_bucket)

# Upload Jamie's proposals
aws s3 sync ./jamies-proposals/ s3://${BUCKET}/proposals/ \
  --profile AdministratorAccess-380414079195
```

## How to Use

### Creating a Proposal

1. **Gather Requirements** from Patrick/Sharona:
   - Customer name and industry
   - Pain points and requirements
   - Project scope and timeline
   - Budget range

2. **Query Jamie 2.0**:
   ```
   "I need a proposal for [Customer Name], a [industry] company with
   [size] employees. They want to [requirements]. They're concerned
   about [pain points]. Budget is approximately [range]."
   ```

3. **Review and Refine**:
   - Jamie 2.0 will search similar proposals
   - Generate draft in Jamie's style
   - Iterate based on feedback

### Example Prompts

**Cloud Migration Proposal**:
```
Create a proposal for Acme Financial, a mid-sized bank with 500
employees looking to migrate 30 applications from on-premises to AWS.
Main concerns: security, compliance (PCI-DSS), and minimal downtime.
Budget: $250k-500k. Timeline: 6 months.
```

**DevOps Transformation**:
```
Need a SOW for RetailCorp's DevOps transformation. They have 20
developers, currently deploying manually. Want CI/CD, infrastructure
as code, and monitoring. Budget: $150k. Start: Q1 2025.
```

## Architecture (Cost-Effective!)

```
┌─────────────────┐
│ Patrick/Sharona │
│  (Voice/Text)   │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│  Bedrock Agent      │◄──── Jamie's Persona
│  (Claude 3.5)       │      & System Prompt
└────────┬────────────┘
         │
         ├──► Lambda Function ──► S3 Bucket
         │    (Doc Search)        (Proposals/SOWs)
         │
         ▼
    Generated Proposal
```

**Monthly Cost: ~$5-20** (No expensive vector DB!)

## What's Included

```
jamie2.0/
├── README.md              # Project overview
├── QUICKSTART.md          # This file
├── jamie-persona.md       # Jamie's writing style (TO COMPLETE)
├── terraform/             # Infrastructure code
│   ├── main-simple.tf     # Cost-effective setup (recommended)
│   └── variables.tf
├── lambda/                # Document search function
│   └── jamie_retriever.py
├── prompts/               # System prompts
│   └── jamie-system-prompt.txt
└── docs/                  # Additional documentation
    ├── DEPLOYMENT.md      # Detailed deployment guide
    └── s3-structure.md    # How to organize proposals
```

## Next Steps

1.  Complete `jamie-persona.md` with Jamie's style
2.  Upload 10+ example proposals to S3
3.  Test with real pre-sales scenario
4. ⏳ Build simple web UI for easy access
5. ⏳ Add voice dictation for Patrick

## Getting Help

- Check `docs/DEPLOYMENT.md` for detailed instructions
- Review CloudWatch logs: `/aws/lambda/jamie2-document-retriever`
- Test Lambda function directly in AWS Console
- Verify S3 bucket has proposals uploaded

## Important Notes

⚠ **Before Going Live**:
- Complete Jamie's persona analysis (most critical!)
- Upload at least 10 diverse proposals
- Test with various customer scenarios
- Get Patrick's approval on sample outputs

💡 **Tips for Best Results**:
- More example proposals = better output
- Add metadata tags to S3 files
- Keep persona guide updated
- Iterate on system prompt based on feedback
- Document successful patterns

## Future Enhancements

- [ ] Web UI for easy interaction
- [ ] Voice dictation (Amazon Transcribe)
- [ ] Multi-language support
- [ ] CRM integration
- [ ] Proposal version tracking
- [ ] Win/loss analysis
