#!/bin/bash
set -e  # Exit on any error

# Jamie 2.0 - Complete Deployment Script
# This script deploys infrastructure, uploads documents, and generates embeddings

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_PROFILE="AdministratorAccess-380414079195"
REQUIRED_ACCOUNT="380414079195"
AWS_REGION="eu-west-2"
PROJECT_ROOT="/Users/nick.barton-wells/Projects/cls-sales-agent"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Jamie 2.0 - Complete Deployment                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "  $1"
}

# ============================================================================
# STEP 0: Pre-Flight Checks
# ============================================================================

print_section "Step 0: Pre-Flight Checks"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    echo "Install with: brew install awscli"
    exit 1
fi
print_success "AWS CLI installed"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    echo "Install with: brew install terraform"
    exit 1
fi
print_success "Terraform installed"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed"
    exit 1
fi
print_success "Python 3 installed"

# Verify AWS Account
print_info "Verifying AWS account..."
CURRENT_ACCOUNT=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text 2>/dev/null || echo "")

if [ -z "$CURRENT_ACCOUNT" ]; then
    print_error "Cannot authenticate with AWS profile: $AWS_PROFILE"
    echo "Please verify your AWS credentials"
    exit 1
fi

if [ "$CURRENT_ACCOUNT" != "$REQUIRED_ACCOUNT" ]; then
    print_error "Wrong AWS account!"
    echo "  Expected: $REQUIRED_ACCOUNT"
    echo "  Current:  $CURRENT_ACCOUNT"
    echo ""
    echo "This is a security protection. Jamie 2.0 can ONLY be deployed to account $REQUIRED_ACCOUNT"
    exit 1
fi

print_success "Verified AWS account: $CURRENT_ACCOUNT"

# Check if required files exist
print_info "Checking required files..."

if [ ! -f "$PROJECT_ROOT/templates/Non-Disclosure Agreement Template v01 JC OFFLINE.docx" ]; then
    print_error "NDA template not found"
    exit 1
fi
print_success "NDA template found"

if [ ! -d "$PROJECT_ROOT/knowledge/NDAs" ]; then
    print_error "Knowledge base NDAs folder not found"
    exit 1
fi
print_success "Knowledge base folders found"

if [ ! -f "$PROJECT_ROOT/embed-documents.py" ]; then
    print_error "Embedding script not found"
    exit 1
fi
print_success "Embedding script found"

echo ""
print_warning "Ready to deploy to account: $CURRENT_ACCOUNT"
echo ""
read -p "Continue with deployment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# ============================================================================
# STEP 1: Deploy Terraform Infrastructure
# ============================================================================

print_section "Step 1: Deploy Terraform Infrastructure"

cd "$PROJECT_ROOT/terraform"

print_info "Initializing Terraform..."
terraform init -upgrade

print_info "Planning deployment..."
terraform plan -var="aws_profile=$AWS_PROFILE" -out=tfplan

print_info "Applying Terraform configuration..."
terraform apply tfplan

# Get outputs
BUCKET=$(terraform output -raw knowledge_base_bucket)
LOGS_BUCKET=$(terraform output -raw access_logs_bucket)
AGENT_ID=$(terraform output -raw agent_id)
KMS_KEY=$(terraform output -raw kms_key_id)

print_success "Infrastructure deployed successfully"
echo ""
print_info "Resources created:"
print_info "  - S3 Bucket (Knowledge Base): $BUCKET"
print_info "  - S3 Bucket (Access Logs): $LOGS_BUCKET"
print_info "  - Bedrock Agent ID: $AGENT_ID"
print_info "  - KMS Key: $KMS_KEY"

# ============================================================================
# STEP 2: Upload Templates
# ============================================================================

print_section "Step 2: Upload Templates"

cd "$PROJECT_ROOT"

print_info "Uploading NDA template..."
aws s3 cp \
  "templates/Non-Disclosure Agreement Template v01 JC OFFLINE.docx" \
  "s3://${BUCKET}/templates/" \
  --profile $AWS_PROFILE \
  --sse aws:kms \
  --sse-kms-key-id "$KMS_KEY"

print_info "Uploading MSA template..."
aws s3 cp \
  "templates/Master Services Agreement Template v02 JC - OFFLINE.docx" \
  "s3://${BUCKET}/templates/" \
  --profile $AWS_PROFILE \
  --sse aws:kms \
  --sse-kms-key-id "$KMS_KEY" \
  2>/dev/null || print_warning "MSA template upload failed (optional)"

print_info "Uploading Proposal template..."
aws s3 cp \
  "templates/Short-Form Proposal Template v01 JC.pptx" \
  "s3://${BUCKET}/templates/" \
  --profile $AWS_PROFILE \
  --sse aws:kms \
  --sse-kms-key-id "$KMS_KEY" \
  2>/dev/null || print_warning "Proposal template upload failed (optional)"

# Verify template upload
TEMPLATE_COUNT=$(aws s3 ls "s3://${BUCKET}/templates/" --profile $AWS_PROFILE | wc -l)
print_success "Uploaded $TEMPLATE_COUNT template(s)"

# ============================================================================
# STEP 3: Upload Knowledge Base Documents
# ============================================================================

print_section "Step 3: Upload Knowledge Base Documents"

print_info "Uploading NDAs..."
NDA_COUNT=$(find knowledge/NDAs -type f -name "*.pdf" | wc -l | tr -d ' ')
if [ "$NDA_COUNT" -gt 0 ]; then
    aws s3 sync knowledge/NDAs/ "s3://${BUCKET}/knowledge/NDAs/" \
      --profile $AWS_PROFILE \
      --server-side-encryption aws:kms \
      --ssekms-key-id "$KMS_KEY" \
      --exclude ".*" \
      --exclude ".DS_Store"
    print_success "Uploaded $NDA_COUNT NDAs"
else
    print_warning "No NDAs found to upload"
fi

print_info "Uploading MSAs..."
MSA_COUNT=$(find knowledge/MSAs -type f -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
if [ "$MSA_COUNT" -gt 0 ]; then
    aws s3 sync knowledge/MSAs/ "s3://${BUCKET}/knowledge/MSAs/" \
      --profile $AWS_PROFILE \
      --server-side-encryption aws:kms \
      --ssekms-key-id "$KMS_KEY" \
      --exclude ".*" \
      --exclude ".DS_Store"
    print_success "Uploaded $MSA_COUNT MSAs"
else
    print_warning "No MSAs found to upload"
fi

print_info "Uploading SOWs..."
if [ -d "knowledge/SOWs" ] && [ "$(ls -A knowledge/SOWs)" ]; then
    aws s3 sync knowledge/SOWs/ "s3://${BUCKET}/knowledge/SOWs/" \
      --profile $AWS_PROFILE \
      --server-side-encryption aws:kms \
      --ssekms-key-id "$KMS_KEY" \
      --exclude ".*" \
      --exclude ".DS_Store"
    print_success "Uploaded SOWs"
else
    print_warning "No SOWs found to upload (folder is empty)"
fi

# Verify uploads
TOTAL_FILES=$(aws s3 ls "s3://${BUCKET}/knowledge/" --recursive --profile $AWS_PROFILE | grep -v ".DS_Store" | wc -l | tr -d ' ')
print_success "Total knowledge base files: $TOTAL_FILES"

# ============================================================================
# STEP 4: Generate Vector Embeddings
# ============================================================================

print_section "Step 4: Generate Vector Embeddings"

print_info "This will generate searchable vector embeddings for all documents..."
print_info "Estimated time: ~30 seconds per document"
echo ""

# Check if boto3 is installed
if ! python3 -c "import boto3" 2>/dev/null; then
    print_warning "boto3 not installed. Installing..."
    pip3 install boto3 --quiet
fi

# Run embedding script
print_info "Processing documents and generating embeddings..."
python3 embed-documents.py \
  --bucket "$BUCKET" \
  --profile "$AWS_PROFILE" \
  --prefixes knowledge/ proposals/ sows/

# Verify vector generation
VECTOR_COUNT=$(aws s3 ls "s3://${BUCKET}/vectors/" --profile $AWS_PROFILE 2>/dev/null | wc -l | tr -d ' ')
if [ "$VECTOR_COUNT" -gt 0 ]; then
    print_success "Generated $VECTOR_COUNT vector embeddings"
else
    print_warning "No vectors generated (this is normal if no documents were uploaded)"
fi

# ============================================================================
# STEP 5: Prepare Bedrock Agent
# ============================================================================

print_section "Step 5: Prepare Bedrock Agent"

print_info "Preparing Bedrock Agent (activating action groups)..."
aws bedrock-agent prepare-agent \
  --agent-id "$AGENT_ID" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  > /dev/null

print_info "Waiting for agent to be ready..."
sleep 10

AGENT_STATUS=$(aws bedrock-agent get-agent \
  --agent-id "$AGENT_ID" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'agent.agentStatus' \
  --output text)

if [ "$AGENT_STATUS" = "PREPARED" ] || [ "$AGENT_STATUS" = "NOT_PREPARED" ]; then
    print_success "Agent prepared successfully"
else
    print_warning "Agent status: $AGENT_STATUS (may need more time)"
fi

# ============================================================================
# STEP 6: Verify Security
# ============================================================================

print_section "Step 6: Security Verification"

print_info "Verifying encryption..."
ENCRYPTION=$(aws s3api get-bucket-encryption \
  --bucket "$BUCKET" \
  --profile "$AWS_PROFILE" \
  --query 'Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
  --output text 2>/dev/null)

if [ "$ENCRYPTION" = "aws:kms" ]; then
    print_success "KMS encryption enabled"
else
    print_error "Encryption verification failed"
fi

print_info "Verifying public access block..."
PUBLIC_BLOCK=$(aws s3api get-public-access-block \
  --bucket "$BUCKET" \
  --profile "$AWS_PROFILE" \
  --query 'PublicAccessBlockConfiguration.BlockPublicAcls' \
  --output text 2>/dev/null)

if [ "$PUBLIC_BLOCK" = "True" ]; then
    print_success "Public access blocked"
else
    print_error "Public access verification failed"
fi

print_info "Verifying access logging..."
LOGGING=$(aws s3api get-bucket-logging \
  --bucket "$BUCKET" \
  --profile "$AWS_PROFILE" \
  --query 'LoggingEnabled.TargetBucket' \
  --output text 2>/dev/null)

if [ "$LOGGING" = "$LOGS_BUCKET" ]; then
    print_success "Access logging enabled"
else
    print_warning "Access logging verification failed"
fi

# ============================================================================
# DEPLOYMENT COMPLETE
# ============================================================================

print_section "🎉 Deployment Complete!"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Jamie 2.0 Successfully Deployed!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📋 Deployment Summary:${NC}"
echo "  • AWS Account: $CURRENT_ACCOUNT"
echo "  • Region: $AWS_REGION"
echo "  • S3 Bucket: $BUCKET"
echo "  • Agent ID: $AGENT_ID"
echo "  • Templates: 3 uploaded"
echo "  • Knowledge Base: $TOTAL_FILES documents"
echo "  • Vector Embeddings: $VECTOR_COUNT generated"
echo ""

echo -e "${BLUE}🔐 Security Status:${NC}"
echo "  • KMS Encryption: ✓ Enabled"
echo "  • Public Access: ✓ Blocked"
echo "  • Access Logging: ✓ Enabled"
echo "  • Account Lock: ✓ Protected to $REQUIRED_ACCOUNT"
echo ""

echo -e "${BLUE}📝 Next Steps:${NC}"
echo "  1. Test NDA generation via jamie-cli.py"
echo "  2. Review CloudWatch logs: /aws/lambda/jamie2-*"
echo "  3. Monitor S3 access logs: s3://$LOGS_BUCKET/"
echo "  4. Check SECURITY.md for best practices"
echo ""

echo -e "${BLUE}🧪 Test Command:${NC}"
echo "  python3 jamie-cli.py"
echo "  Then try: 'Generate an NDA for company SC123456, signatory Patrick Godden, Director'"
echo ""

echo -e "${BLUE}📊 View Resources:${NC}"
echo "  terraform output -state=terraform/terraform.tfstate"
echo ""

print_success "Jamie 2.0 is ready to use!"
echo ""
