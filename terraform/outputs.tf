# DEPLOYMENT VERIFICATION
output "aws_account_id" {
  description = "AWS Account ID (MUST be 380414079195)"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

output "deployment_verification" {
  description = "Verify deployment to correct account"
  value       = "✓ Deployed to account ${data.aws_caller_identity.current.account_id} in ${var.aws_region}"
}

# S3 BUCKETS
output "knowledge_base_bucket" {
  description = "S3 bucket for Jamie's knowledge base (SENSITIVE DATA)"
  value       = aws_s3_bucket.jamie_knowledge_base.id
}

output "access_logs_bucket" {
  description = "S3 bucket for access logs (audit trail)"
  value       = aws_s3_bucket.jamie_access_logs.id
}

# SECURITY
output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.jamie_kb_key.id
}

output "kms_key_alias" {
  description = "KMS key alias"
  value       = aws_kms_alias.jamie_kb_key_alias.name
}

# BEDROCK AGENT
output "agent_id" {
  description = "Bedrock Agent ID for Jamie 2.0"
  value       = aws_bedrockagent_agent.jamie.agent_id
}

output "agent_alias_id" {
  description = "Production alias ID for Jamie 2.0"
  value       = aws_bedrockagent_agent_alias.jamie_prod.agent_alias_id
}

output "agent_arn" {
  description = "Bedrock Agent ARN"
  value       = aws_bedrockagent_agent.jamie.agent_arn
}

# LAMBDA FUNCTIONS
output "lambda_functions" {
  description = "Lambda function names"
  value = {
    document_retriever = aws_lambda_function.jamie_document_retriever.function_name
    nda_generator      = aws_lambda_function.jamie_nda_generator.function_name
    vector_search      = aws_lambda_function.jamie_vector_search.function_name
  }
}

# USAGE INSTRUCTIONS
output "upload_instructions" {
  description = "Instructions for uploading documents"
  value       = <<-EOT
  📁 Upload locations:
  - Knowledge: s3://${aws_s3_bucket.jamie_knowledge_base.id}/knowledge/
  - Proposals: s3://${aws_s3_bucket.jamie_knowledge_base.id}/proposals/
  - SOWs:      s3://${aws_s3_bucket.jamie_knowledge_base.id}/sows/
  - Templates: s3://${aws_s3_bucket.jamie_knowledge_base.id}/templates/

  🔒 All data encrypted with KMS key: ${aws_kms_key.jamie_kb_key.id}
  📊 Access logs: s3://${aws_s3_bucket.jamie_access_logs.id}/
  EOT
}

output "embed_documents_command" {
  description = "Command to generate vector embeddings"
  value       = "./embed-documents.py --bucket ${aws_s3_bucket.jamie_knowledge_base.id} --profile AdministratorAccess-380414079195"
}
