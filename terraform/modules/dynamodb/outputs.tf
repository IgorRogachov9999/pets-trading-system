output "connections_table_name" {
  description = "DynamoDB table name for WebSocket connection tracking."
  value       = aws_dynamodb_table.connections.name
}

output "table_name" {
  description = "Alias for connections_table_name — used by IAM module variable binding."
  value       = aws_dynamodb_table.connections.name
}

output "connections_table_arn" {
  description = "DynamoDB table ARN — used in IAM policy scoping."
  value       = aws_dynamodb_table.connections.arn
}
