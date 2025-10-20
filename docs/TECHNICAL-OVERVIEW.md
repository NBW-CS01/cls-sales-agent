# Jamie 2.0 - Technical Overview

## How Technology Enables the Strategic Vision

### Strategic Vision
Jamie 2.0 aims to democratize sales proposal generation by capturing Jamie's writing style and institutional knowledge, making it accessible to the entire pre-sales team (Patrick, Sharona, and future team members) without requiring Jamie's direct involvement in every proposal.

### Technology Enablement

#### 1. **AI-Powered Content Generation**
- **Amazon Bedrock with Claude Sonnet 4.5**: Leverages state-of-the-art large language model to understand requirements and generate human-quality proposals
- **Conversational Interface**: Natural language interaction allows non-technical users to describe customer needs without learning complex systems
- **Context-Aware Generation**: Agent architecture maintains conversation context for iterative refinement

#### 2. **Knowledge Management & Retrieval**
- **S3-Based Knowledge Base**: Flat, simple structure makes it easy to add/update proposals without complex data engineering
- **Serverless Search**: Lambda-based document retrieval eliminates need for expensive vector databases while maintaining sub-second search performance
- **Action Groups**: Bedrock Agent action groups enable Jamie to dynamically search past proposals during content generation

#### 3. **Cost-Effective Architecture**
- **Serverless-First Design**: Pay-per-use model means costs scale with usage (~$5-20/month vs $700+/month for traditional RAG solutions)
- **No Infrastructure Management**: Fully managed AWS services eliminate operational overhead
- **Efficient Storage**: Simple S3 structure with intelligent tiering optimizes storage costs

#### 4. **Developer Experience**
- **Infrastructure as Code**: Terraform ensures reproducible, version-controlled deployments
- **CLI Tool**: Simple Python CLI provides immediate productivity without web UI development
- **Local Execution**: Team members run Jamie from their terminal with simple AWS SSO authentication

#### 5. **Extensibility**
- **Template System**: PowerPoint templates stored in S3 enable branded output formats
- **Multi-Format Output**: Text and presentation formats support different customer engagement scenarios
- **Future-Ready**: Architecture designed for easy addition of S3 Vectors when GA for semantic search

---

## Technical Constraints

### Regional Constraints
- **Primary Region**: `eu-west-2` (London)
  - **Rationale**:
    - Data residency compliance for UK-based company
    - Low latency for UK-based users (Patrick, Sharona)
    - Proximity to customer data
  - **Services Used**:
    - Amazon Bedrock (Claude 4.5 Sonnet available in eu-west-2)
    - Lambda (document retrieval)
    - S3 (knowledge base storage)
    - IAM (roles and permissions)
    - CloudWatch (logging and monitoring)

### Service Constraints

#### Amazon Bedrock
- **Model Access Required**: Claude Sonnet 4.5 must be enabled in AWS account
  - Manual enablement required via Bedrock console
  - Subject to AWS's model access approval process
- **Quota Limits**:
  - Default: 10 requests/minute for Claude models
  - Can be increased via service quota increase request
- **Cost Constraints**:
  - Input tokens: $0.003 per 1K tokens
  - Output tokens: $0.015 per 1K tokens
  - Typical proposal generation: ~10K input + 5K output = $0.11 per proposal

#### Lambda Constraints
- **Runtime**: Python 3.12
- **Memory**: 512 MB (configurable)
- **Timeout**: 30 seconds for document search
- **Concurrent Executions**: Default 1000 (more than sufficient for team usage)
- **Cold Start**: 1-2 seconds initial latency acceptable for this use case

#### S3 Constraints
- **Bucket Naming**: Must be globally unique (hence: jamie2-knowledge-base-0t76l52f)
- **Object Size**: Individual proposals typically < 1 MB
- **No Public Access**: Bucket locked down to IAM roles only
- **Versioning Enabled**: Protects against accidental deletion/overwrite
- **Encryption**: Server-side encryption (SSE-S3) enabled by default

#### IAM Constraints
- **Least Privilege**: Each service has minimal required permissions
- **No Long-Term Credentials**: Uses AWS SSO (AdministratorAccess-380414079195 profile)
- **Service Roles Only**: Lambda and Bedrock Agent use service-linked roles

### Technology Stack Constraints
- **Python 3.12+**: Required for modern boto3 features and type hints
- **Terraform**: Infrastructure deployment requires Terraform 1.0+
- **Local Dependencies**:
  - `boto3`: AWS SDK
  - `python-pptx`: PowerPoint generation
  - AWS CLI configured with SSO

### Operational Constraints
- **No 24/7 Availability Requirement**: Team works UK business hours
- **No High Availability**: Single region deployment acceptable (proposals aren't mission-critical)
- **No Disaster Recovery**: S3 versioning provides sufficient protection
- **Manual Scaling**: Current team size (2-3 users) doesn't require auto-scaling

---

## Cloud Platform Strategy

### Cloud Placement Strategy

#### AWS (Primary Platform)
**Services Hosted on AWS:**
-  **AI/ML Workloads**: Amazon Bedrock for LLM inference
-  **Serverless Compute**: Lambda for document retrieval
-  **Object Storage**: S3 for knowledge base
-  **Identity & Access**: IAM for authentication/authorization
-  **Logging & Monitoring**: CloudWatch
-  **Infrastructure Management**: All resources deployed via Terraform

**Rationale for AWS:**
- Native Bedrock integration (Claude models not available on Azure OpenAI in same regions)
- Mature serverless ecosystem (Lambda + S3)
- Strong UK region presence (eu-west-2)
- Cost-effective for this use case
- Team familiarity with AWS

#### Azure (Not Used)
**Rationale for Not Using Azure:**
- No equivalent to Bedrock Agents with Claude models
- Would require custom orchestration layer
- Higher operational complexity for marginal benefit
- No existing Azure infrastructure to leverage

#### Multi-Cloud Strategy
**Current**: Single-cloud (AWS only)
**Future Consideration**: Could use Azure OpenAI if:
- GPT models prove superior for proposal generation
- Cost becomes prohibitive on AWS Bedrock
- Customer requirements mandate Azure hosting

---

## Current State

### Infrastructure Overview

#### On-Premises Infrastructure
**Status**: None

Jamie 2.0 is a cloud-native, greenfield project with no on-premises dependencies.

#### Cloud Infrastructure (AWS)

**Existing Services:**
```
┌─────────────────────────────────────────────────┐
│ AWS Account: 380414079195                       │
│ Region: eu-west-2 (London)                      │
├─────────────────────────────────────────────────┤
│                                                 │
│ ┌─────────────────────────────────────────┐   │
│ │ Amazon Bedrock                           │   │
│ │ - Agent: jamie2 (LUZWQYYBP4)            │   │
│ │ - Model: Claude Sonnet 4.5              │   │
│ │ - Alias: prod (65PC3XRFMX)              │   │
│ │ - Cost: ~$0.11 per proposal             │   │
│ └─────────────────────────────────────────┘   │
│                                                 │
│ ┌─────────────────────────────────────────┐   │
│ │ AWS Lambda                               │   │
│ │ - Function: jamie2-document-retriever   │   │
│ │ - Runtime: Python 3.12                  │   │
│ │ - Memory: 512 MB                        │   │
│ │ - Cost: ~$1/month                       │   │
│ └─────────────────────────────────────────┘   │
│                                                 │
│ ┌─────────────────────────────────────────┐   │
│ │ Amazon S3                                │   │
│ │ - Bucket: jamie2-knowledge-base-0t76l52f│   │
│ │ - Structure:                             │   │
│ │   • proposals/                          │   │
│ │   • sows/                               │   │
│ │   • templates/                          │   │
│ │ - Size: < 1 GB (starting)               │   │
│ │ - Cost: ~$0.50/month                    │   │
│ └─────────────────────────────────────────┘   │
│                                                 │
│ ┌─────────────────────────────────────────┐   │
│ │ CloudWatch Logs                          │   │
│ │ - Log Group: /aws/lambda/jamie2-...    │   │
│ │ - Retention: 7 days                     │   │
│ │ - Cost: ~$0.50/month                    │   │
│ └─────────────────────────────────────────┘   │
│                                                 │
│ ┌─────────────────────────────────────────┐   │
│ │ IAM                                      │   │
│ │ - Role: jamie2-agent-role               │   │
│ │ - Role: jamie2-lambda-role              │   │
│ │ - User Auth: AWS SSO                    │   │
│ └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘
```

#### Related Infrastructure
**Project Alice** (separate demo environment):
- Location: `/Users/nick.barton-wells/Projects/project-alice-demo`
- Purpose: Security remediation demo
- Status: Active, separate from Jamie 2.0
- Shared: AWS Account (380414079195)
- Isolated: Different resources, no dependencies

### Business Service Portfolio

#### Services Deployed
1. **Jamie 2.0 Proposal Generator** (Production)
   - Status:  Deployed and operational
   - Users: Patrick, Sharona
   - Function: Generate sales proposals and SOWs
   - Availability: On-demand via CLI
   - SLA: Best effort, UK business hours

#### Services to Migrate
**Status**: N/A - No migration required

Jamie 2.0 is a new build, not a migration project. All services were designed cloud-native from inception.

### Current Pain Points & Limitations

#### 1. **Search Capability Limitations**
- **Current State**: Simple keyword-based search in Lambda
- **Pain Point**: Cannot find semantically similar proposals (e.g., "cloud security" won't match "AWS protection")
- **Impact**: May miss relevant past proposals, reducing quality
- **Mitigation Path**: Implement S3 Vectors when GA
- **Priority**: Medium (workaround: use specific keywords)

#### 2. **PowerPoint Template Integration**
- **Current State**: Template stored in S3, but conversion is post-processing
- **Pain Point**:
  - Jamie generates text, then separate script converts to PPTX
  - Doesn't follow template instructions during generation
  - Manual formatting may be required
- **Impact**: Extra step, less polished output
- **Mitigation Path**: Build Lambda action group for PPTX generation
- **Priority**: High (customer-facing deliverable)

#### 3. **No Multi-Format Output from Agent**
- **Current State**: Bedrock Agent only returns text
- **Pain Point**: Cannot generate PDF, DOCX, XLSX directly
- **Impact**: Limited to text proposals or post-processing conversion
- **Mitigation Path**: Lambda action groups for format conversion
- **Priority**: Medium (text format acceptable for now)

#### 4. **Knowledge Base Size**
- **Current State**: Only 1-2 proposals uploaded
- **Pain Point**: Limited examples for Jamie to learn from
- **Impact**: Output quality depends on Jamie's base model knowledge, not company-specific style
- **Mitigation Path**: Upload 20-50 historical proposals
- **Priority**: High (directly impacts output quality)

#### 5. **No Feedback Loop**
- **Current State**: No mechanism to capture which proposals win/lose
- **Pain Point**: Cannot improve Jamie's recommendations over time
- **Impact**: Missed opportunity for continuous improvement
- **Mitigation Path**: DynamoDB table tracking proposal outcomes
- **Priority**: Low (future enhancement)

#### 6. **Single Region Deployment**
- **Current State**: Only eu-west-2 (London)
- **Pain Point**: If region unavailable, Jamie unavailable
- **Impact**: Low (non-critical application, UK team)
- **Mitigation Path**: Multi-region deployment if business grows
- **Priority**: Low (acceptable risk)

#### 7. **Model Selection Fixed**
- **Current State**: Hard-coded to Claude Sonnet 4.5
- **Pain Point**: Cannot A/B test other models (GPT-4, Claude Opus, etc.)
- **Impact**: May not be using optimal model for proposal generation
- **Mitigation Path**: Configurable model selection in CLI
- **Priority**: Low (Sonnet 4.5 performs well)

#### 8. **No Usage Analytics**
- **Current State**: Basic CloudWatch logs only
- **Pain Point**: Don't know which types of proposals are most requested
- **Impact**: Cannot prioritize template/example development
- **Mitigation Path**: CloudWatch Insights queries or DynamoDB tracking
- **Priority**: Low (small team size)

#### 9. **Authentication Limited to AWS SSO**
- **Current State**: Requires AWS SSO profile configured locally
- **Pain Point**: Onboarding friction for new team members
- **Impact**: ~15 minutes setup time per user
- **Mitigation Path**: Web UI with auth, or API gateway with tokens
- **Priority**: Low (2-3 users acceptable with CLI)

#### 10. **No Version Control for Outputs**
- **Current State**: Proposals saved locally, no central storage
- **Pain Point**: Cannot track revisions or see proposal history
- **Impact**: May recreate work, lose track of iterations
- **Mitigation Path**: Auto-upload outputs to S3 with metadata
- **Priority**: Medium (quality of life improvement)

---

## Recommendations for Improvement

### Short Term (1-4 weeks)
1. **Upload Historical Proposals**: Add 20-50 past proposals to S3
2. **Complete Jamie Persona**: Fill in jamie-persona.md with actual writing style examples
3. **Test PowerPoint Template**: Validate template conversion with real proposals
4. **Document Onboarding**: Create team onboarding guide for new users

### Medium Term (1-3 months)
1. **Implement S3 Vectors**: Upgrade to semantic search when feature is GA
2. **Build PPTX Action Group**: Lambda function for native PowerPoint generation
3. **Add Usage Analytics**: CloudWatch dashboard for proposal generation metrics
4. **Multi-Format Support**: Add PDF generation capability

### Long Term (3-6 months)
1. **Feedback Loop**: Track proposal win/loss rates
2. **Web Interface**: Simple web UI for non-technical users
3. **Integration**: Connect to CRM (Salesforce, HubSpot) for automated proposal creation
4. **Advanced Features**: Multi-language support, industry-specific templates

---

## Architecture Decisions

### Why Serverless?
- **Cost**: Pay-per-use aligns with sporadic proposal generation
- **Scalability**: Auto-scales from 0 to production load
- **Maintenance**: Zero server patching/management
- **Speed**: Fast deployment and iteration

### Why Bedrock over SageMaker?
- **Simplicity**: Managed model serving vs self-hosting
- **Cost**: No infrastructure overhead
- **Agent Framework**: Built-in orchestration and tool calling
- **Model Access**: Latest Claude models without deployment complexity

### Why Simple S3 Search over Vector Database?
- **Cost**: $5/month vs $700/month (OpenSearch Serverless)
- **Complexity**: No index management, no cluster tuning
- **Scale**: Current knowledge base (< 100 proposals) works fine with simple search
- **Future Path**: Easy migration to S3 Vectors when needed

### Why Terraform over ClickOps?
- **Reproducibility**: Can recreate environment in minutes
- **Version Control**: Infrastructure changes tracked in Git
- **Documentation**: Code serves as living documentation
- **Safety**: Prevents accidental deletions/modifications
- **Team Collaboration**: Multiple team members can contribute

---

## Conclusion

Jamie 2.0 successfully demonstrates how modern cloud services can democratize specialized knowledge (proposal writing) through cost-effective, serverless AI architecture. The current constraints are appropriate for the team size and use case, with clear paths for enhancement as usage grows.

**Key Success Factors:**
-  Simple, maintainable architecture
-  Cost-effective (< $20/month)
-  Easy to use (CLI tool)
-  Quick to deploy (Terraform)
-  Room to grow (S3 Vectors, action groups)

**Technical Maturity**: Production-ready for current team size with identified paths for scaling.
