output "sg_rds_id" {
  description = "Security group ID for RDS PostgreSQL."
  value       = aws_security_group.rds.id
}

output "db_endpoint" {
  description = "RDS instance endpoint hostname (without port)."
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS instance port."
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name."
  value       = aws_db_instance.main.db_name
}

output "db_resource_id" {
  description = "RDS resource ID — used in IAM auth policy Resource ARN."
  value       = aws_db_instance.main.resource_id
}
