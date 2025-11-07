# Jamie 2.0 - Simplified Cost-Effective Architecture
# Uses Bedrock Agent + Lambda to search S3 directly (no expensive vector DB)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # CRITICAL SECURITY CONTROL: Only allow deployment to account 380414079195
  # This prevents accidental deployment to wrong AWS accounts
  allowed_account_ids = [var.allowed_aws_account_id]
}

# Validation: Ensure we're deploying to the correct account
locals {
  current_account_id = data.aws_caller_identity.current.account_id

  # This will fail terraform plan/apply if wrong account
  validate_account = (
    local.current_account_id == var.allowed_aws_account_id
    ? local.current_account_id
    : file("ERROR: Deployment to account ${local.current_account_id} is not allowed. Must be ${var.allowed_aws_account_id}")
  )
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket for Jamie's knowledge base (proposals, SOWs, NDAs, etc.)
# SECURITY: This bucket contains highly sensitive commercial information
resource "aws_s3_bucket" "jamie_knowledge_base" {
  bucket = "jamie2-knowledge-base-${random_string.suffix.result}"

  tags = {
    Name         = "jamie2-knowledge-base"
    Purpose      = "Sales proposals and SOW repository"
    Environment  = var.environment
    DataClass    = "Confidential"
    Compliance   = "NDA-Protected"
  }
}

# Enable versioning (allows recovery of deleted/modified sensitive docs)
resource "aws_s3_bucket_versioning" "jamie_knowledge_base_versioning" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id
  versioning_configuration {
    status = "Enabled"
    # MFA delete provides additional protection
    mfa_delete = "Disabled"  # Enable manually via CLI with MFA device
  }
}

# Encrypt at rest with KMS (more secure than AES256)
resource "aws_kms_key" "jamie_kb_key" {
  description             = "KMS key for Jamie 2.0 knowledge base encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name    = "jamie2-kb-encryption-key"
    Purpose = "Knowledge base encryption"
  }
}

resource "aws_kms_alias" "jamie_kb_key_alias" {
  name          = "alias/jamie2-knowledge-base"
  target_key_id = aws_kms_key.jamie_kb_key.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "jamie_knowledge_base_encryption" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.jamie_kb_key.arn
    }
    bucket_key_enabled = true
  }
}

# Block ALL public access (critical for sensitive data)
resource "aws_s3_bucket_public_access_block" "jamie_knowledge_base_public_access" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable access logging for audit trail
resource "aws_s3_bucket" "jamie_access_logs" {
  bucket = "jamie2-access-logs-${random_string.suffix.result}"

  tags = {
    Name    = "jamie2-access-logs"
    Purpose = "Audit trail for knowledge base access"
  }
}

resource "aws_s3_bucket_public_access_block" "jamie_logs_public_access" {
  bucket = aws_s3_bucket.jamie_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "jamie_logs_encryption" {
  bucket = aws_s3_bucket.jamie_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "jamie_knowledge_base_logging" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id

  target_bucket = aws_s3_bucket.jamie_access_logs.id
  target_prefix = "knowledge-base-access/"
}

# Lifecycle policy - retain sensitive data but manage costs
resource "aws_s3_bucket_lifecycle_configuration" "jamie_knowledge_base_lifecycle" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365  # Keep versions for 1 year
    }
  }

  rule {
    id     = "expire-generated-ndas"
    status = "Enabled"

    filter {
      prefix = "generated-ndas/"
    }

    expiration {
      days = 90  # Generated NDAs auto-delete after 90 days
    }
  }
}

# Bucket policy - strict access control
resource "aws_s3_bucket_policy" "jamie_knowledge_base_policy" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.jamie_knowledge_base.arn,
          "${aws_s3_bucket.jamie_knowledge_base.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.jamie_knowledge_base.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.jamie_knowledge_base.arn,
          "${aws_s3_bucket.jamie_knowledge_base.arn}/*"
        ]
      }
    ]
  })

  depends_on = [aws_iam_role.lambda_role]
}

# Lambda function to search and retrieve documents from S3
resource "aws_lambda_function" "jamie_document_retriever" {
  filename         = "jamie_retriever.zip"
  function_name    = "jamie2-document-retriever"
  role            = aws_iam_role.lambda_role.arn
  handler         = "jamie_retriever.lambda_handler"
  runtime         = "python3.12"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      KNOWLEDGE_BASE_BUCKET = aws_s3_bucket.jamie_knowledge_base.bucket
      REGION                = var.aws_region
    }
  }

  depends_on = [data.archive_file.lambda_zip]
}

# Lambda function for NDA generation
# NOTE: Build deployment package with: cd lambda && ./build-nda-package.sh
resource "aws_lambda_function" "jamie_nda_generator" {
  filename         = "nda_generator.zip"
  function_name    = "jamie2-nda-generator"
  role            = aws_iam_role.lambda_role.arn
  handler         = "nda_generator.lambda_handler"
  runtime         = "python3.12"
  timeout         = 120
  memory_size     = 1024
  source_code_hash = filebase64sha256("nda_generator.zip")

  environment {
    variables = {
      KNOWLEDGE_BASE_BUCKET    = aws_s3_bucket.jamie_knowledge_base.bucket
      REGION                   = var.aws_region
      COMPANIES_HOUSE_API_KEY  = var.companies_house_api_key
    }
  }
}

# Create Lambda deployment package for document retriever
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "jamie_retriever.zip"
  source_file = "../lambda/jamie_retriever.py"
}

# NOTE: NDA generator package is built manually using lambda/build-nda-package.sh
# This is necessary because it requires Python dependencies (requests, python-docx, lxml)

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "jamie2-lambda-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda policy for S3 and CloudWatch
resource "aws_iam_role_policy" "lambda_policy" {
  name = "jamie2-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.jamie_knowledge_base.arn,
          "${aws_s3_bucket.jamie_knowledge_base.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.jamie_kb_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-7-sonnet-20250219-v1:0"
        ]
      }
    ]
  })
}

# Lambda permission for Bedrock Agent - Document Retriever
resource "aws_lambda_permission" "allow_bedrock_retriever" {
  statement_id  = "AllowExecutionFromBedrock"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jamie_document_retriever.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.jamie.agent_arn
}

# Lambda permission for Bedrock Agent - NDA Generator
resource "aws_lambda_permission" "allow_bedrock_nda" {
  statement_id  = "AllowExecutionFromBedrockNDA"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jamie_nda_generator.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.jamie.agent_arn
}


# Lambda function for vector search (ALICE-style with S3 + NumPy)
# Cost-effective alternative to OpenSearch Serverless (~$0.35/month vs $700/month)
resource "aws_lambda_function" "jamie_vector_search" {
  filename         = "vector_search.zip"
  function_name    = "jamie2-vector-search"
  role            = aws_iam_role.lambda_role.arn
  handler         = "vector_search.lambda_handler"
  runtime         = "python3.12"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      KNOWLEDGE_BASE_BUCKET = aws_s3_bucket.jamie_knowledge_base.bucket
      REGION                = var.aws_region
    }
  }

  depends_on = [data.archive_file.vector_search_zip]
}

# Create Lambda deployment package for vector search
data "archive_file" "vector_search_zip" {
  type        = "zip"
  output_path = "vector_search.zip"
  source_dir  = "../lambda"
  excludes    = ["jamie_retriever.py", "nda_generator.py", "companies_house.py"]
}

# Lambda permission for Bedrock Agent - Vector Search
resource "aws_lambda_permission" "allow_bedrock_vector" {
  statement_id  = "AllowExecutionFromBedrockVector"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jamie_vector_search.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.jamie.agent_arn
}

# IAM role for Bedrock Agent
resource "aws_iam_role" "jamie_agent_role" {
  name = "jamie2-agent-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"
          }
        }
      }
    ]
  })
}

# IAM policy for Agent to invoke models and Lambda
resource "aws_iam_role_policy" "jamie_agent_policy" {
  name = "jamie2-agent-policy"
  role = aws_iam_role.jamie_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-7-sonnet-20250219-v1:0"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.jamie_document_retriever.arn,
          aws_lambda_function.jamie_nda_generator.arn,
          aws_lambda_function.jamie_vector_search.arn
        ]
      }
    ]
  })
}

# Bedrock Agent - Jamie 2.0
resource "aws_bedrockagent_agent" "jamie" {
  agent_name              = "jamie2"
  agent_resource_role_arn = aws_iam_role.jamie_agent_role.arn
  foundation_model        = "anthropic.claude-3-7-sonnet-20250219-v1:0"

  description = "AI Sales Proposal Assistant - Generates proposals and SOWs in Jamie's writing style"

  instruction = file("${path.module}/../prompts/jamie-system-prompt.txt")

  idle_session_ttl_in_seconds = 600

  tags = {
    Name        = "jamie2-agent"
    Purpose     = "Sales proposal generation"
    Environment = var.environment
  }
}

# Action group for document retrieval
resource "aws_bedrockagent_agent_action_group" "document_search" {
  action_group_name          = "DocumentSearch"
  agent_id                   = aws_bedrockagent_agent.jamie.agent_id
  agent_version              = "DRAFT"
  skip_resource_in_use_check = true

  description = "Search and retrieve similar proposals and SOWs from Jamie's document repository"

  action_group_executor {
    lambda = aws_lambda_function.jamie_document_retriever.arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "searchProposals"
        description = "Search for similar proposals based on customer requirements, industry, or keywords"
        parameters {
          map_block_key = "query"
          type          = "string"
          description   = "Search query describing customer needs, industry, or requirements"
          required      = true
        }
        parameters {
          map_block_key = "max_results"
          type          = "integer"
          description   = "Maximum number of documents to return (default: 5)"
          required      = false
        }
      }
    }
  }
}

# Action group for NDA generation
resource "aws_bedrockagent_agent_action_group" "nda_generation" {
  action_group_name          = "NDAGeneration"
  agent_id                   = aws_bedrockagent_agent.jamie.agent_id
  agent_version              = "DRAFT"
  skip_resource_in_use_check = true

  description = "Generate Non-Disclosure Agreements using Companies House data and NDA templates"

  action_group_executor {
    lambda = aws_lambda_function.jamie_nda_generator.arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "generateNDA"
        description = "Generate an NDA for a company by fetching details from Companies House and populating the template"
        parameters {
          map_block_key = "company_identifier"
          type          = "string"
          description   = "Company name or Companies House registration number (e.g., '01234567' or 'SC123456' or 'Acme Ltd')"
          required      = true
        }
        parameters {
          map_block_key = "signatory_name"
          type          = "string"
          description   = "Full name of the person who will sign the NDA"
          required      = true
        }
        parameters {
          map_block_key = "signatory_title"
          type          = "string"
          description   = "Job title/position of the signatory (e.g., 'Director', 'CEO', 'Managing Partner')"
          required      = true
        }
      }
    }
  }
}

# Action group for vector search
resource "aws_bedrockagent_agent_action_group" "vector_search" {
  action_group_name          = "VectorSearch"
  agent_id                   = aws_bedrockagent_agent.jamie.agent_id
  agent_version              = "DRAFT"
  skip_resource_in_use_check = true

  description = "Semantic search across proposals, SOWs, and NDAs using vector embeddings"

  action_group_executor {
    lambda = aws_lambda_function.jamie_vector_search.arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "searchDocuments"
        description = "Search for similar documents using semantic search (vector similarity)"
        parameters {
          map_block_key = "query"
          type          = "string"
          description   = "Search query describing what you're looking for (e.g., 'cloud migration proposal', 'financial services NDA')"
          required      = true
        }
        parameters {
          map_block_key = "max_results"
          type          = "integer"
          description   = "Maximum number of results to return (default: 5, max: 20)"
          required      = false
        }
        parameters {
          map_block_key = "similarity_threshold"
          type          = "number"
          description   = "Minimum similarity score from 0.0 to 1.0 (default: 0.3)"
          required      = false
        }
      }
    }
  }
}

# Agent alias for production use
resource "aws_bedrockagent_agent_alias" "jamie_prod" {
  agent_id         = aws_bedrockagent_agent.jamie.agent_id
  agent_alias_name = "prod"
  description      = "Production alias for Jamie 2.0"

  depends_on = [
    aws_bedrockagent_agent.jamie,
    aws_bedrockagent_agent_action_group.document_search,
    aws_bedrockagent_agent_action_group.nda_generation,
    aws_bedrockagent_agent_action_group.vector_search
  ]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_retriever_logs" {
  name              = "/aws/lambda/jamie2-document-retriever"
  retention_in_days = 7

  tags = {
    Project = "jamie2"
    Purpose = "lambda-logs"
  }
}

resource "aws_cloudwatch_log_group" "lambda_nda_logs" {
  name              = "/aws/lambda/jamie2-nda-generator"
  retention_in_days = 7

  tags = {
    Project = "jamie2"
    Purpose = "lambda-logs"
  }
}

resource "aws_cloudwatch_log_group" "lambda_vector_logs" {
  name              = "/aws/lambda/jamie2-vector-search"
  retention_in_days = 7

  tags = {
    Project = "jamie2"
    Purpose = "lambda-logs"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
