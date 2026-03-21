# ==============================================================================
# outputs.tf — Aggregated root module outputs
# Consumed by CI/CD pipelines and operational runbooks.
# pets-trading-system
# ==============================================================================

output "vpc_id" {
  description = "VPC ID."
  value       = module.networking.vpc_id
}

output "ecr_trading_api_url" {
  description = "ECR repository URL for the Trading API container image."
  value       = module.ecr.trading_api_repository_url
}

output "ecr_lifecycle_lambda_url" {
  description = "ECR repository URL for the Lifecycle Lambda container image."
  value       = module.ecr.lifecycle_lambda_repository_url
}

# Alias used by initial-setup.yml
output "trading_api_ecr_url" {
  description = "ECR repository URL for the Trading API container image (CI/CD alias)."
  value       = module.ecr.trading_api_repository_url
}

output "lifecycle_lambda_ecr_url" {
  description = "ECR repository URL for the Lifecycle Lambda container image (CI/CD alias)."
  value       = module.ecr.lifecycle_lambda_repository_url
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for the frontend SPA."
  value       = module.s3_cloudfront.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — required for cache invalidation in CI/CD."
  value       = module.s3_cloudfront.cloudfront_distribution_id
}

output "frontend_s3_bucket_name" {
  description = "S3 bucket name for frontend asset deployment."
  value       = module.s3_cloudfront.s3_bucket_name
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID."
  value       = module.cognito.user_pool_id
}

output "cognito_web_client_id" {
  description = "Cognito App Client ID for the React SPA."
  value       = module.cognito.web_client_id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint hostname."
  value       = module.rds.db_endpoint
}

output "alb_dns_name" {
  description = "Internal ALB DNS name (API Gateway VPC Link target)."
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name for the Trading API."
  value       = module.ecs.ecs_service_name
}

output "lambda_function_name" {
  description = "Lifecycle Lambda function name."
  value       = module.lambda.lambda_function_name
}

output "rest_api_url" {
  description = "API Gateway REST API invoke URL."
  value       = module.api_gateway.rest_api_url
}

output "websocket_api_endpoint" {
  description = "API Gateway WebSocket API endpoint."
  value       = module.api_gateway.websocket_api_endpoint
}

output "builds_bucket_name" {
  description = "S3 bucket name for CI/CD build artifact storage."
  value       = module.s3_cloudfront.builds_bucket_name
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — use as the assume-role target in workflows."
  value       = aws_iam_role.github_actions.arn
}
