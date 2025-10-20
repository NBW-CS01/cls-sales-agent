# S3 Knowledge Base Structure

## Overview
The S3 bucket contains Jamie's historical proposals, SOWs, and reference materials organized for easy retrieval.

## Directory Structure

**Simple flat structure with just 2 folders:**

```
s3://jamie2-knowledge-base-{random}/
│
├── proposals/                    # All customer proposals
│   ├── 2024-03-15_acme-corp_cloud-migration_v2.pdf
│   ├── 2024-04-20_techco_devops-transformation_final.pdf
│   ├── 2023-11-10_retailcorp_security-compliance_v1.docx
│   └── ...
│
└── sows/                         # All statements of work
    ├── 2024-04-01_acme-corp_aws-migration_final.pdf
    ├── 2024-05-15_techco_cicd-pipeline_signed.pdf
    ├── 2023-12-20_retailcorp_pen-testing_v3.docx
    └── ...
```

**Benefits of flat structure:**
- Simple to navigate and maintain
- Easy to upload files
- Fast search/retrieval (no nested directory traversal)
- Less prone to organizational errors
- Metadata tags provide filtering instead of folders

## File Naming Convention

### Proposals
Format: `{YYYY-MM-DD}_{customer-name}_{solution-type}_{version}.{ext}`

Example: `2024-03-15_acme-corp_cloud-migration_v2.pdf`

### SOWs
Format: `{YYYY-MM-DD}_{customer-name}_{project-name}_{status}.{ext}`

Example: `2024-04-01_acme-corp_aws-migration_final.pdf`

### Metadata Tags (S3 Object Tags)
Apply consistent metadata tags to help with searching:
- `industry`: financial-services, healthcare, retail, etc.
- `solution`: cloud-migration, devops, security, etc.
- `customer_size`: enterprise, mid-market, smb
- `deal_size`: <50k, 50k-250k, 250k-1m, >1m
- `status`: draft, submitted, won, lost
- `year`: 2024, 2023, etc.

## Supported File Formats
- **PDF**: Preferred for proposals and SOWs
- **DOCX**: Microsoft Word documents
- **TXT**: Plain text documents
- **MD**: Markdown files
- **JSON**: Structured data

## Upload Instructions

### Using AWS CLI
```bash
# Set your bucket name
BUCKET_NAME=$(terraform -chdir=terraform output -raw knowledge_base_bucket)

# Upload a proposal with metadata
aws s3 cp proposal.pdf s3://${BUCKET_NAME}/proposals/2024-03-15_acme-corp_cloud-migration_v2.pdf \
  --metadata industry=financial-services,solution=cloud-migration,customer_size=enterprise \
  --profile AdministratorAccess-380414079195

# Upload a SOW
aws s3 cp sow.pdf s3://${BUCKET_NAME}/sows/2024-04-01_acme-corp_aws-migration_final.pdf \
  --metadata industry=financial-services,solution=cloud-migration,status=signed \
  --profile AdministratorAccess-380414079195

# Upload all proposals from a local directory
aws s3 sync ./local-proposals/ s3://${BUCKET_NAME}/proposals/ \
  --profile AdministratorAccess-380414079195

# Upload all SOWs
aws s3 sync ./local-sows/ s3://${BUCKET_NAME}/sows/ \
  --profile AdministratorAccess-380414079195
```

### Using AWS Console
1. Navigate to S3 bucket: `jamie2-knowledge-base-{random}`
2. Click on `proposals/` or `sows/` folder
3. Upload files directly to that folder
4. Add metadata tags for better search (optional but recommended)
5. Ensure files are encrypted (AES256 - automatic)

## Best Practices

1. **Consistent Naming**: Always use the naming convention
2. **Add Metadata Tags**: Use S3 object tags for filtering (industry, solution, status, customer_size)
3. **Version Control**: Keep proposal versions with v1, v2, v3 in filename
4. **Clean Old Versions**: Archive or remove outdated proposals periodically
5. **Sanitize Customer Data**: Remove sensitive information before uploading
6. **Descriptive Filenames**: Include customer name and solution type in filename

## Initial Setup Checklist

- [ ] Create 2 folders in S3: `proposals/` and `sows/`
- [ ] Upload at least 10 example proposals for Jamie to learn from
- [ ] Upload 5-10 SOWs for reference
- [ ] Document Jamie's writing style in jamie-persona.md
- [ ] Test document retrieval with Lambda function
- [ ] Verify Bedrock Agent can access documents

## Maintenance

- **Weekly**: Review new proposals and add to knowledge base
- **Monthly**: Update capabilities and service offerings
- **Quarterly**: Archive old proposals, update pricing templates
- **Annually**: Review and refresh all templates and reference materials
