# Web Frontend Infrastructure for Jamie NDA Generator
# Simple, low-cost static website with API Gateway backend

# ============================================================================
# API Gateway HTTP API (cheaper than REST API)
# ============================================================================

resource "aws_apigatewayv2_api" "nda_api" {
  name          = "jamie-nda-api"
  protocol_type = "HTTP"
  description   = "API for Jamie NDA Generator web frontend"

  cors_configuration {
    allow_origins = ["*"] # JWT authorizer provides the real security
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }

  tags = {
    Name        = "jamie-nda-api"
    Environment = var.environment
  }
}

# API Gateway Stage (auto-deploy) with Rate Limiting
resource "aws_apigatewayv2_stage" "nda_api_default" {
  api_id      = aws_apigatewayv2_api.nda_api.id
  name        = "$default"
  auto_deploy = true

  # Rate limiting: 10 requests per second, burst of 20
  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      error          = "$context.error.message"
      authorizerError = "$context.authorizer.error"
    })
  }

  tags = {
    Name = "jamie-nda-api-default"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/jamie-nda-api"
  retention_in_days = 7

  tags = {
    Name = "jamie-nda-api-logs"
  }
}

# ============================================================================
# Lambda Function for API Handler
# ============================================================================

# Lambda function to handle API requests and invoke Bedrock Agent
resource "aws_lambda_function" "nda_api_handler" {
  filename      = "${path.module}/nda_api_handler.zip"
  function_name = "jamie-nda-api-handler"
  role          = aws_iam_role.nda_api_handler_role.arn
  handler       = "nda_api_handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  source_code_hash = fileexists("${path.module}/nda_api_handler.zip") ? filebase64sha256("${path.module}/nda_api_handler.zip") : null

  environment {
    variables = {
      AGENT_ID       = aws_bedrockagent_agent.jamie.agent_id
      AGENT_ALIAS_ID = aws_bedrockagent_agent_alias.jamie_prod.agent_alias_id
    }
  }

  tags = {
    Name        = "jamie-nda-api-handler"
    Environment = var.environment
  }
}

# IAM Role for API Handler Lambda
resource "aws_iam_role" "nda_api_handler_role" {
  name = "jamie-nda-api-handler-role"

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

  tags = {
    Name = "jamie-nda-api-handler-role"
  }
}

# IAM Policy for API Handler Lambda
resource "aws_iam_role_policy" "nda_api_handler_policy" {
  name = "jamie-nda-api-handler-policy"
  role = aws_iam_role.nda_api_handler_role.id

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
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/jamie-nda-api-handler:*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent"
        ]
        Resource = [
          aws_bedrockagent_agent.jamie.agent_arn,
          "${aws_bedrockagent_agent.jamie.agent_arn}/*",
          "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent-alias/${aws_bedrockagent_agent.jamie.agent_id}/*"
        ]
      }
    ]
  })
}

# API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "nda_lambda_integration" {
  api_id           = aws_apigatewayv2_api.nda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.nda_api_handler.invoke_arn

  payload_format_version = "2.0"
}

# API Gateway Route with Authorization
resource "aws_apigatewayv2_route" "nda_generate" {
  api_id             = aws_apigatewayv2_api.nda_api.id
  route_key          = "POST /generate-nda"
  target             = "integrations/${aws_apigatewayv2_integration.nda_lambda_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt_authorizer.id
}

# Lambda permission for API Gateway to invoke
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nda_api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.nda_api.execution_arn}/*/*"
}

# ============================================================================
# S3 Bucket for Static Website
# ============================================================================

resource "aws_s3_bucket" "web_app" {
  bucket = "jamie-nda-web-${random_string.suffix.result}"

  tags = {
    Name        = "jamie-nda-web"
    Environment = var.environment
  }
}

# Block public access (CloudFront will access via OAC)
resource "aws_s3_bucket_public_access_block" "web_app" {
  bucket = aws_s3_bucket.web_app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for CloudFront OAC
resource "aws_s3_bucket_policy" "web_app" {
  bucket = aws_s3_bucket.web_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.web_app.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.web_app.arn
          }
        }
      }
    ]
  })
}

# ============================================================================
# CloudFront Distribution
# ============================================================================

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "web_app" {
  name                              = "jamie-nda-web-oac"
  description                       = "OAC for Jamie NDA web app"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "web_app" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Jamie NDA Generator Web App"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # Use only North America & Europe (cheapest)

  origin {
    domain_name              = aws_s3_bucket.web_app.bucket_regional_domain_name
    origin_id                = "S3-jamie-nda-web"
    origin_access_control_id = aws_cloudfront_origin_access_control.web_app.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-jamie-nda-web"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "jamie-nda-web"
    Environment = var.environment
  }
}
