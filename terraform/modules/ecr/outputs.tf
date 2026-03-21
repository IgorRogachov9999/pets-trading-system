output "trading_api_repository_url" {
  description = "ECR repository URL for the Trading API container image."
  value       = aws_ecr_repository.trading_api.repository_url
}

output "lifecycle_lambda_repository_url" {
  description = "ECR repository URL for the Lifecycle Lambda container image."
  value       = aws_ecr_repository.lifecycle_lambda.repository_url
}
