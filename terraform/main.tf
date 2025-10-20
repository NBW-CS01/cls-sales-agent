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
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket for Jamie's knowledge base (proposals, SOWs, etc.)
resource "aws_s3_bucket" "jamie_knowledge_base" {
  bucket = "jamie2-knowledge-base-${random_string.suffix.result}"

  tags = {
    Name        = "jamie2-knowledge-base"
    Purpose     = "Sales proposals and SOW repository"
    Environment = var.environment
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "jamie_knowledge_base_versioning" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "jamie_knowledge_base_encryption" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "jamie_knowledge_base_public_access" {
  bucket = aws_s3_bucket.jamie_knowledge_base.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "jamie_retriever.zip"
  source_dir  = "../lambda"
}

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
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
        ]
      }
    ]
  })
}

# Lambda permission for Bedrock Agent
resource "aws_lambda_permission" "allow_bedrock" {
  statement_id  = "AllowExecutionFromBedrock"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jamie_document_retriever.function_name
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
          aws_lambda_function.jamie_document_retriever.arn
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

# Agent alias for production use
resource "aws_bedrockagent_agent_alias" "jamie_prod" {
  agent_id         = aws_bedrockagent_agent.jamie.agent_id
  agent_alias_name = "prod"
  description      = "Production alias for Jamie 2.0"

  depends_on = [
    aws_bedrockagent_agent.jamie,
    aws_bedrockagent_agent_action_group.document_search
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/jamie2-document-retriever"
  retention_in_days = 7

  tags = {
    Project = "jamie2"
    Purpose = "lambda-logs"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
