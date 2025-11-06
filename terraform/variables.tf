variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "AdministratorAccess-380414079195"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "companies_house_api_key" {
  description = "Companies House API key (optional - free tier available at https://developer.company-information.service.gov.uk/)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "allowed_aws_account_id" {
  description = "The ONLY AWS account ID allowed for deployment (security control)"
  type        = string
  default     = "380414079195"
}
