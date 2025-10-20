output "knowledge_base_bucket" {
  description = "S3 bucket for Jamie's knowledge base"
  value       = aws_s3_bucket.jamie_knowledge_base.id
}

output "agent_id" {
  description = "Bedrock Agent ID for Jamie 2.0"
  value       = aws_bedrockagent_agent.jamie.agent_id
}

output "agent_alias_id" {
  description = "Production alias ID for Jamie 2.0"
  value       = aws_bedrockagent_agent_alias.jamie_prod.agent_alias_id
}

output "lambda_function_name" {
  description = "Lambda function name for document retrieval"
  value       = aws_lambda_function.jamie_document_retriever.function_name
}

output "upload_instructions" {
  description = "Instructions for uploading documents"
  value       = "Upload proposals to s3://${aws_s3_bucket.jamie_knowledge_base.id}/proposals/ and SOWs to s3://${aws_s3_bucket.jamie_knowledge_base.id}/sows/"
}
