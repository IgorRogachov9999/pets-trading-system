output "sg_lambda_id" {
  description = "Security group ID for the Lifecycle Lambda."
  value       = aws_security_group.lambda.id
}

output "lambda_function_name" {
  description = "Lifecycle Lambda function name — used in CI/CD update-function-code commands."
  value       = aws_lambda_function.lifecycle.function_name
}

output "lambda_function_arn" {
  description = "Lifecycle Lambda function ARN."
  value       = aws_lambda_function.lifecycle.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role."
  value       = aws_iam_role.lambda_execution.arn
}
