variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, demo)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the Application Load Balancer."
  type        = list(string)
}

variable "private_app_subnet_ids" {
  description = "Private app subnet IDs for ECS Fargate tasks."
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block — used to scope ECS egress to RDS port within the VPC."
  type        = string
}

variable "sg_vpce_id" {
  description = "Security group ID for VPC Interface Endpoints — ECS tasks egress HTTPS to this SG."
  type        = string
}

variable "trading_api_image_url" {
  description = "ECR image URL for the Trading API container. Updated by CI/CD with SHA tag."
  type        = string
}

variable "desired_count" {
  description = "Desired number of ECS task instances. Use 1 for dev, 2 for demo (multi-AZ)."
  type        = number
  default     = 1
}

variable "ecs_cpu" {
  description = "ECS task CPU units."
  type        = string
  default     = "512"
}

variable "ecs_memory" {
  description = "ECS task memory in MiB."
  type        = string
  default     = "1024"
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 30
}

variable "dynamodb_table_name" {
  description = "DynamoDB WebSocket connections table name — used to scope ECS task IAM policy."
  type        = string
}

variable "aws_region" {
  description = "AWS region — used in log configuration and IAM policy ARNs."
  type        = string
  default     = "us-east-1"
}
