# Authentication Infrastructure for Jamie NDA Web App
# AWS Cognito User Pool for secure user management

# ============================================================================
# Cognito User Pool
# ============================================================================

resource "aws_cognito_user_pool" "nda_users" {
  name = "jamie-nda-users"

  # Password policy
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Auto-verified attributes
  auto_verified_attributes = ["email"]

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = false

    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # MFA configuration (optional for Phase 1, but available)
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED" # Protects against compromised credentials
  }

  # Account takeover protection
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  tags = {
    Name        = "jamie-nda-users"
    Environment = var.environment
  }
}

# User Pool Domain (for hosted UI)
resource "aws_cognito_user_pool_domain" "nda_domain" {
  domain       = "jamie-nda-${random_string.suffix.result}"
  user_pool_id = aws_cognito_user_pool.nda_users.id
}

# ============================================================================
# Cognito User Pool Client (Web App)
# ============================================================================

resource "aws_cognito_user_pool_client" "nda_web_client" {
  name         = "jamie-nda-web-client"
  user_pool_id = aws_cognito_user_pool.nda_users.id

  # OAuth configuration
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  # Callback URLs (will be CloudFront URL)
  callback_urls = [
    "https://${aws_cloudfront_distribution.web_app.domain_name}",
    "https://${aws_cloudfront_distribution.web_app.domain_name}/callback",
    "http://localhost:8000" # For local testing
  ]

  logout_urls = [
    "https://${aws_cloudfront_distribution.web_app.domain_name}",
    "http://localhost:8000"
  ]

  # Token validity
  id_token_validity      = 60  # 60 minutes
  access_token_validity  = 60  # 60 minutes
  refresh_token_validity = 30  # 30 days

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }

  # Prevent secret for public client (JavaScript app)
  generate_secret = false

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]

  # Attribute read/write permissions
  read_attributes = [
    "email",
    "email_verified",
    "name"
  ]

  write_attributes = [
    "email",
    "name"
  ]

  # Prevent user existence errors (security best practice)
  prevent_user_existence_errors = "ENABLED"

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# ============================================================================
# API Gateway Authorizer
# ============================================================================

resource "aws_apigatewayv2_authorizer" "jwt_authorizer" {
  api_id           = aws_apigatewayv2_api.nda_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.nda_web_client.id]
    issuer   = "https://${aws_cognito_user_pool.nda_users.endpoint}"
  }
}

# ============================================================================
# CloudWatch Log Group for Cognito
# ============================================================================

resource "aws_cloudwatch_log_group" "cognito_logs" {
  name              = "/aws/cognito/jamie-nda-users"
  retention_in_days = 30

  tags = {
    Name = "jamie-cognito-logs"
  }
}

# ============================================================================
# Initial Admin User (Optional - can be created via CLI after deployment)
# ============================================================================

# Note: We'll create users via AWS CLI after deployment for security
# Example command will be provided in outputs
