output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (ALB, NAT GW)."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of private app subnet IDs (ECS, Lambda)."
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "List of private DB subnet IDs (RDS). Always 2 for subnet group compatibility."
  value       = aws_subnet.private_db[*].id
}

output "sg_vpce_id" {
  description = "Security group ID for VPC Interface Endpoints — passed to ECS and Lambda modules for HTTPS egress."
  value       = aws_security_group.vpce.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block — passed to ECS and Lambda modules to scope RDS egress rules."
  value       = aws_vpc.main.cidr_block
}
