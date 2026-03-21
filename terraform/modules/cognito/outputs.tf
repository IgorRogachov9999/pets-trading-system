output "user_pool_id" {
  description = "Cognito User Pool ID."
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN — used by API Gateway Cognito authorizer."
  value       = aws_cognito_user_pool.main.arn
}

output "web_client_id" {
  description = "Cognito App Client ID for the React SPA."
  value       = aws_cognito_user_pool_client.web.id
}
