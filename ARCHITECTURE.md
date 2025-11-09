# Jamie 2.0 - System Architecture

## System Overview

Jamie 2.0 is an AI-powered document generation platform that automatically creates NDAs and MSAs using Companies House data. The system combines AWS Bedrock Agent with a web frontend to provide both a conversational interface and user-friendly document generation.

## Current Capabilities

### Document Generation
- **NDA Generation**: Automated Non-Disclosure Agreement creation
- **MSA Generation**: Automated Master Services Agreement creation
- **Multi-Document**: Can generate both NDA and MSA in a single request
- **Companies House Integration**: Automatic company data lookup and validation
- **Template Population**: Word document mail merge with company details

### User Interfaces
1. **Web Application**: Authenticated web UI via CloudFront
2. **CLI Tool**: Command-line interface for power users (future/legacy)
3. **Bedrock Agent**: Natural language conversational interface

### Authentication & Security
- **AWS Cognito**: User pool authentication for web frontend
- **JWT Authorization**: API Gateway JWT authorizer
- **IAM Roles**: Service-to-service authentication
- **S3 Presigned URLs**: Temporary, secure document downloads (1-hour expiration)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                  USER                                    │
│                          (Web Browser / CLI)                             │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                 ┌───────────────┴──────────────┐
                 │                              │
                 │ HTTPS                        │ CLI (future)
                 │                              │
┌────────────────▼─────────┐      ┌─────────────▼──────────────┐
│   CloudFront CDN         │      │   Local Terminal           │
│   dvwns88zneoxo...       │      │   (AWS SSO Auth)           │
└────────────────┬─────────┘      └─────────────┬──────────────┘
                 │                              │
                 │ Static Assets                │ Direct Invoke
                 │                              │
┌────────────────▼─────────┐      ┌─────────────▼──────────────┐
│   S3 Web Bucket          │      │   Bedrock Agent            │
│   jamie-nda-web-...      │      │   (LUZWQYYBP4)             │
│                          │      │   Claude Sonnet 4.5        │
│   - index.html           │      └─────────────┬──────────────┘
│   - logo.png             │                    │
│   - Cognito SDK          │                    │
└──────────────────────────┘                    │
                                                │
┌────────────────────────────────────────────────┘
│
│ USER LOGIN (from web)
│
▼
┌────────────────────────────────────────────────┐
│   Amazon Cognito User Pool                     │
│   eu-west-2_an6Z5oLfp                         │
│                                                │
│   Users:                                       │
│   - patrick.godden@cloudscaler.co.uk          │
│   - nick.barton-wells@cloudscaler.com         │
│                                                │
│   Returns: JWT ID Token                        │
└────────────────────────────────────────────────┘
                 │
                 │ JWT Token in Authorization header
                 │
                 ▼
┌────────────────────────────────────────────────┐
│   API Gateway HTTP API                         │
│   rjh7m6u0nj.execute-api.eu-west-2...         │
│                                                │
│   Route: POST /generate-nda                    │
│   Authorizer: JWT (Cognito)                    │
│   Timeout: 30 seconds (hard limit)             │
│   Rate Limit: 10 req/s, burst 20               │
└────────────────┬───────────────────────────────┘
                 │
                 │ Proxy Integration
                 │
┌────────────────▼───────────────────────────────┐
│   Lambda: jamie-nda-api-handler                │
│   Runtime: Python 3.12                         │
│   Timeout: 120 seconds                         │
│   Memory: 128 MB                               │
│                                                │
│   Responsibilities:                            │
│   - Parse request (company, signatory, types)  │
│   - Build prompt for Bedrock Agent             │
│   - Invoke agent with streaming enabled        │
│   - Extract documents from agent traces        │
│   - Early return when all docs collected       │
│     (prevents API Gateway 30s timeout)         │
│   - Return structured JSON response            │
└────────────────┬───────────────────────────────┘
                 │
                 │ bedrock-agent-runtime:invoke_agent
                 │
┌────────────────▼───────────────────────────────┐
│   Amazon Bedrock Agent                         │
│   ID: LUZWQYYBP4                               │
│   Alias: 65PC3XRFMX (prod)                     │
│   Model: Claude Sonnet 4.5                     │
│                                                │
│   System Prompt:                               │
│   - Jamie's writing style and persona          │
│   - NDA/MSA generation instructions            │
│   - Companies House API usage guidelines       │
│                                                │
│   Action Groups:                               │
│   - NDAGeneration (generateNDA)                │
│   - MSAGeneration (generateMSA)                │
│   - DocumentSearch (search proposals)          │
│   - VectorSearch (future semantic search)      │
└──────┬──────────────────────┬──────────────────┘
       │                      │
       │ Invoke Action        │ Invoke Action
       │ Group                │ Group
       │                      │
┌──────▼─────────────┐  ┌─────▼──────────────────┐
│   Lambda:          │  │   Lambda:              │
│   jamie2-nda-      │  │   jamie2-msa-          │
│   generator        │  │   generator            │
│                    │  │                        │
│   Runtime: 3.12    │  │   Runtime: 3.12        │
│   Timeout: 120s    │  │   Timeout: 120s        │
│   Memory: 1024 MB  │  │   Memory: 1024 MB      │
│                    │  │                        │
│   Dependencies:    │  │   Dependencies:        │
│   - python-docx    │  │   - python-docx        │
│   - requests       │  │   - requests           │
│   - lxml           │  │   - lxml               │
│                    │  │                        │
│   Process:         │  │   Process:             │
│   1. Get company # │  │   1. Get company #     │
│   2. Fetch CH data │  │   2. Fetch CH data     │
│   3. Load template │  │   3. Load template     │
│   4. Populate doc  │  │   4. Populate doc      │
│   5. Save to S3    │  │   5. Save to S3        │
│   6. Generate URL  │  │   6. Generate URL      │
│   7. Return JSON   │  │   7. Return JSON       │
└──────┬─────────────┘  └─────┬──────────────────┘
       │                      │
       │ HTTPS API Call       │ HTTPS API Call
       │                      │
┌──────▼──────────────────────▼──────────────────┐
│   Companies House API                          │
│   api.company-information.service.gov.uk       │
│                                                │
│   Endpoints Used:                              │
│   - GET /company/{number}                      │
│   - GET /search/companies?q={name}             │
│                                                │
│   Returns:                                     │
│   - Company name, number, type                 │
│   - Registered office address                  │
│   - Jurisdiction, status, creation date        │
└────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│   S3: jamie2-knowledge-base-0t76l52f            │
│   Region: eu-west-2                             │
│   Encryption: KMS (696b446b-84cf-44bf-...)      │
│                                                 │
│   Structure:                                    │
│   ├── templates/                                │
│   │   ├── Non-Disclosure Agreement...v01.docx   │
│   │   └── Master Services Agreement...v02.docx  │
│   ├── generated-ndas/                           │
│   │   └── NDA_{COMPANY}_{TIMESTAMP}.docx        │
│   ├── generated-msas/                           │
│   │   └── MSA_{COMPANY}_{TIMESTAMP}.docx        │
│   ├── proposals/ (legacy)                       │
│   ├── sows/ (legacy)                            │
│   └── knowledge/ (legacy)                       │
│                                                 │
│   Access:                                       │
│   - Lambda execution roles (read/write)         │
│   - Presigned URLs (public, 1-hour expiry)      │
└─────────────────────────────────────────────────┘
```

---

## Data Flow

### Document Generation Flow (NDA + MSA)

**Timeline: 12-15 seconds total**

1. **User Submits Form** (Web UI)
   - Company: "Ravens of Ingatestone Limited"
   - Signatory: "Nick Barton-Wells", "Director"
   - Document Types: [NDA, MSA] ✓

2. **Frontend → API Gateway** (< 1s)
   - POST to `/generate-nda`
   - Headers: `Authorization: Bearer {JWT_TOKEN}`
   - Body: JSON with company, signatory, document_types

3. **API Gateway → Lambda Handler** (< 1s)
   - JWT validation via Cognito
   - Rate limiting check (10 req/s)
   - Proxy to Lambda

4. **Lambda Handler → Bedrock Agent** (~0.5s)
   - Builds prompt: "I need both an NDA and MSA for {company}..."
   - Invokes agent with streaming enabled
   - Monitors event stream for document traces

5. **Bedrock Agent Processing** (~11s streaming)
   - **NDA Generation** (~6s)
     - Agent decides to call `generateNDA()` action
     - Invokes NDA Lambda
     - NDA Lambda queries Companies House
     - Downloads NDA template from S3
     - Populates template fields
     - Saves to S3 `generated-ndas/`
     - Generates presigned URL (1-hour expiry)
     - Returns JSON with download URL

   - **MSA Generation** (~5s)
     - Agent decides to call `generateMSA()` action
     - Invokes MSA Lambda
     - MSA Lambda queries Companies House (cached)
     - Downloads MSA template from S3
     - Populates template fields
     - Saves to S3 `generated-msas/`
     - Generates presigned URL
     - Returns JSON with download URL

   - **Agent Continues** (~49s would stream text response)
     - **OPTIMIZATION**: Lambda exits early at this point
     - Once both documents collected, returns immediately
     - Prevents API Gateway 30-second timeout

6. **Lambda Handler → API Gateway** (< 0.5s)
   - Returns HTTP 200 with JSON:
     ```json
     {
       "success": true,
       "message": "Successfully generated 2 document(s)",
       "company": {
         "name": "RAVENS OF INGATESTONE LIMITED",
         "number": "04109890",
         "type": "Private Limited Company",
         "jurisdiction": "England and Wales",
         "address": "5th Floor..."
       },
       "documents": [
         {
           "type": "nda",
           "download_url": "https://jamie2-knowledge-base...presigned",
           "s3_key": "generated-ndas/NDA_RAVENS_..."
         },
         {
           "type": "msa",
           "download_url": "https://jamie2-knowledge-base...presigned",
           "s3_key": "generated-msas/MSA_RAVENS_..."
         }
       ],
       "expires_in": "1 hour"
     }
     ```

7. **Frontend Displays Results** (< 1s)
   - Shows company details
   - Creates download buttons for each document
   - "Download NDA Document"
   - "Download MSA Document"
   - User clicks → Opens presigned S3 URL → Downloads .docx file

---

## Technology Stack

### Frontend
- **HTML/CSS/JavaScript**: Static single-page application
- **Amazon Cognito SDK**: `amazon-cognito-identity-js` v6.3.6
- **CloudFront**: Global CDN for static assets
- **S3**: Static website hosting

### Backend
- **AWS Bedrock Agent**: Claude Sonnet 4.5 orchestration
- **AWS Lambda**: Python 3.12 serverless functions
- **API Gateway HTTP API**: RESTful endpoint (cheaper than REST API)
- **AWS Cognito**: User authentication
- **Amazon S3**: Document storage and templates
- **AWS KMS**: Encryption at rest

### External Services
- **Companies House API**: UK company data (free tier, no key required but recommended)

### Infrastructure
- **Terraform**: Infrastructure as Code for all AWS resources
- **CloudWatch**: Logging and monitoring (7-day retention)

---

## Security Architecture

### Authentication Flow
1. User enters email/password on web UI
2. Frontend calls Cognito `authenticateUser()`
3. Cognito validates credentials, returns JWT ID token
4. Frontend stores JWT in memory (session only)
5. All API requests include `Authorization: {JWT}` header
6. API Gateway validates JWT signature against Cognito
7. Lambda receives validated user context

### Authorization
- **Web Users**: Must be created in Cognito user pool
- **API Endpoints**: JWT authorizer (Cognito-based)
- **Lambda Execution**: IAM roles with least-privilege permissions
- **S3 Access**:
  - Private bucket (no public access)
  - Lambda writes with execution role
  - Users download via time-limited presigned URLs

### Data Protection
- **In Transit**: HTTPS/TLS for all communications
- **At Rest**: S3 server-side encryption with KMS
- **Secrets**: Companies House API key in environment variables (optional)

### Rate Limiting
- **API Gateway**: 10 requests/second, burst of 20
- **Cognito**: AWS-managed brute force protection
- **Companies House API**: Free tier rate limits apply

---

## Cost Analysis

### Monthly Costs (estimated for moderate usage)

| Service | Usage | Cost |
|---------|-------|------|
| **Bedrock Agent** | ~50 document generations<br>10K input + 5K output per gen | ~$6 |
| **Lambda** | NDA + MSA generators<br>120s timeout, 1GB memory | ~$2 |
| **API Gateway** | 50 requests/month | ~$0.05 |
| **S3 Storage** | < 5 GB documents + templates | ~$0.12 |
| **CloudFront** | < 1 GB transfer | ~$0.10 |
| **Cognito** | 2 active users | Free tier |
| **CloudWatch Logs** | 7-day retention | ~$1 |
| **KMS** | Key storage + operations | ~$1 |
| **TOTAL** | | **~$10-12/month** |

**Scaling**: Costs scale linearly with document generation volume. At 500 docs/month: ~$70/month.

---

## Operational Characteristics

### Performance
- **Document Generation**: 12-15 seconds for both NDA + MSA
- **Single Document**: 6-8 seconds
- **Web Page Load**: < 2 seconds (CloudFront cached)
- **Login**: < 1 second (Cognito)

### Availability
- **Target**: 99.9% (AWS managed services baseline)
- **Region**: Single region (eu-west-2 London)
- **Disaster Recovery**: S3 versioning enabled, no cross-region replication
- **Maintenance Window**: None required (serverless)

### Monitoring
- **CloudWatch Logs**: All Lambda executions logged
- **API Gateway Logs**: Request/response logging with errors
- **Retention**: 7 days
- **Alerts**: None configured (manual monitoring)

### Scaling
- **Lambda**: Auto-scales to 1000 concurrent executions (default)
- **API Gateway**: Auto-scales, rate-limited at 10 req/s
- **S3**: Unlimited storage, 5500 GET requests/second per prefix
- **Bedrock**: Subject to model quotas (10 req/min default)

---

## Deployment Architecture

### Infrastructure as Code
All infrastructure defined in Terraform:
- `terraform/main.tf`: Core resources (Bedrock, Lambda, S3)
- `terraform/web_frontend.tf`: Web app (Cognito, API Gateway, CloudFront)
- `terraform/variables.tf`: Configuration parameters
- `terraform/outputs.tf`: Deployment information

### Deployment Process
```bash
# 1. Build Lambda packages
cd lambda
./build-nda-package.sh  # NDA generator
./build-msa-package.sh  # MSA generator
./build-api-handler.sh  # API Gateway handler

# 2. Deploy infrastructure
cd ../terraform
terraform init
terraform plan
terraform apply

# 3. Configure web app
./configure-web-app.sh  # Injects Cognito/API config into HTML

# 4. Upload web assets
aws s3 sync ../web s3://jamie-nda-web-... --exclude "*.md"

# 5. Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id ... \
  --paths "/*"
```

### Environments
- **Production**: Single environment (eu-west-2)
- **Testing**: Use same environment with test data
- **Staging**: Not implemented (low complexity doesn't warrant it)

---

## Key Design Decisions

### Why API Gateway HTTP API instead of REST API?
- **Cost**: 70% cheaper than REST API
- **Performance**: Lower latency
- **Simplicity**: Simpler configuration for JWT auth
- **Sufficient**: Meets all requirements without REST API's advanced features

### Why Early Return from Bedrock Agent Stream?
- **Problem**: API Gateway has 30-second hard timeout
- **Solution**: Lambda returns immediately once all documents collected (~12s)
- **Benefit**: Don't need to wait for agent's full conversational response
- **Trade-off**: User doesn't see agent's summary text (not needed for web UI)

### Why Presigned URLs instead of API Download Endpoint?
- **Bandwidth**: Offloads download traffic from Lambda/API Gateway to S3
- **Cost**: S3 GET requests cheaper than Lambda GB-seconds
- **Performance**: S3 optimized for large file transfers
- **Simplicity**: No need for streaming logic in Lambda

### Why 1-Hour Presigned URL Expiry?
- **Security**: Short enough to limit exposure if URL leaked
- **Usability**: Long enough for user to download multiple times
- **Compliance**: Documents may contain sensitive company data

### Why Single Region?
- **Users**: UK-based team (Patrick, Nick)
- **Data**: UK Companies House data
- **Compliance**: UK data residency preference
- **Cost**: Multi-region significantly more expensive
- **Risk**: Acceptable for non-critical application

---

## Known Limitations & Future Improvements

### Current Limitations

1. **Company Name Ambiguity**
   - **Issue**: If multiple companies match search, system auto-selects first result
   - **Impact**: May generate document for wrong company
   - **Mitigation**: Users should use company number when ambiguous
   - **Future**: Add company selection UI when multiple matches

2. **API Gateway 30-Second Timeout**
   - **Issue**: Hard limit cannot be increased
   - **Current Mitigation**: Early return optimization (works for ≤2 documents)
   - **Future Issue**: If generating 3+ documents, might timeout
   - **Future Solution**: Async generation with polling or WebSocket

3. **Single Region**
   - **Issue**: If eu-west-2 has outage, service unavailable
   - **Impact**: Low (non-critical business function)
   - **Future**: Multi-region if business criticality increases

4. **No Document Versioning**
   - **Issue**: Can't track document revisions or regenerate identical document
   - **Impact**: User must save manually, no audit trail
   - **Future**: Store generation requests in DynamoDB

5. **Basic Error Handling**
   - **Issue**: Generic error messages don't guide user to resolution
   - **Example**: "Company not found" - doesn't suggest alternatives
   - **Future**: Better error messages with corrective actions

### Planned Improvements

#### Short Term (Next Sprint)
- [ ] Enhanced error messages with user guidance
- [ ] Company selection UI for ambiguous names
- [ ] Admin panel for user management
- [ ] Usage analytics dashboard

#### Medium Term (Next Quarter)
- [ ] Document regeneration from history
- [ ] Batch document generation (multiple companies)
- [ ] Email delivery option
- [ ] Integration with company CRM

#### Long Term (Next 6 Months)
- [ ] Multi-region deployment for HA
- [ ] Additional document types (SOW, MSA variations)
- [ ] Customizable templates per customer
- [ ] Approval workflow for generated documents

---

## Maintenance & Operations

### Regular Maintenance
- **Weekly**: Review CloudWatch logs for errors
- **Monthly**: Check S3 storage costs and lifecycle policies
- **Quarterly**: Review Cognito user list, remove inactive users
- **Annually**: Rotate Companies House API key if used

### Troubleshooting

#### Document Generation Fails
1. Check CloudWatch logs for Lambda errors
2. Verify Companies House API accessibility
3. Confirm templates exist in S3 `templates/` prefix
4. Check Lambda timeout not exceeded

#### User Cannot Login
1. Verify user exists in Cognito user pool
2. Check password is permanent (not temporary)
3. Confirm Cognito config in web app HTML
4. Check browser console for JavaScript errors

#### Download Link Doesn't Work
1. Presigned URLs expire after 1 hour
2. Document must exist in S3 (check CloudWatch logs for Lambda success)
3. S3 bucket policy must allow CloudFront OAC

### Backup & Recovery
- **S3 Versioning**: Enabled on knowledge base bucket
- **Terraform State**: Stored in S3 with versioning
- **User Data**: Cognito user pool (no backup needed, can recreate)
- **Recovery Time**: < 30 minutes to redeploy from Terraform

---

## Compliance & Governance

### Data Residency
- **Region**: EU (London) for UK company compliance
- **Storage**: All data in S3 eu-west-2
- **Processing**: All Lambda functions in eu-west-2
- **Companies House Data**: Sourced from UK government API

### Data Classification
- **Generated Documents**: Confidential (contains company financial data)
- **User Data**: Internal (email addresses of employees)
- **Templates**: Internal (company standard templates)
- **System Logs**: Internal (no sensitive data)

### Retention Policies
- **Generated Documents**: No automatic deletion (manual cleanup)
- **CloudWatch Logs**: 7 days
- **S3 Versioned Objects**: 90 days in previous versions
- **Cognito User Sessions**: 1 hour JWT token expiry

---

## Appendix

### Resource Identifiers
- **AWS Account**: 380414079195
- **Region**: eu-west-2
- **Bedrock Agent ID**: LUZWQYYBP4
- **Agent Alias ID**: 65PC3XRFMX
- **Cognito User Pool**: eu-west-2_an6Z5oLfp
- **Cognito Client ID**: 68gc5j0bvdj5398bdoglim1i6u
- **API Gateway**: rjh7m6u0nj.execute-api.eu-west-2.amazonaws.com
- **Web App**: https://dvwns88zneoxo.cloudfront.net
- **KMS Key**: 696b446b-84cf-44bf-84be-621b21e0f189

### Contact Information
- **System Owner**: Nick Barton-Wells (nick.barton-wells@cloudscaler.com)
- **Primary User**: Patrick Godden (patrick.godden@cloudscaler.co.uk)
- **AWS Account Admin**: AdministratorAccess-380414079195

### Related Documentation
- **README.md**: Project overview and quick start
- **NDA_GENERATION_GUIDE.md**: NDA generation deployment guide
- **DEPLOYMENT.md**: Infrastructure deployment procedures
- **SECURITY.md**: Security best practices
- **docs/TECHNICAL-OVERVIEW.md**: Legacy technical overview (outdated)
