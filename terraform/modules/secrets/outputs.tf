output "db_secret_arn" {
  description = "ARN of the DB connection secret in Secrets Manager."
  value       = aws_secretsmanager_secret.db_connection.arn
}

output "app_config_secret_arn" {
  description = "ARN of the app config secret in Secrets Manager."
  value       = aws_secretsmanager_secret.app_config.arn
}
