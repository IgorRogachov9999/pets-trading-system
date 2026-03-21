variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, demo)."
  type        = string
}

variable "private_app_subnet_ids" {
  description = "Private app subnet IDs for VPC-attached Lambda execution."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID — used to create the Lambda security group."
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block — used to scope Lambda egress to RDS port within the VPC."
  type        = string
}

variable "sg_vpce_id" {
  description = "Security group ID for VPC Interface Endpoints — Lambda egresses HTTPS to this SG."
  type        = string
}

variable "lifecycle_lambda_image_url" {
  description = "ECR image URL for the Lifecycle Lambda container. Updated by CI/CD with SHA tag."
  type        = string
  default     = "placeholder"
}

variable "db_endpoint" {
  description = "RDS instance endpoint hostname."
  type        = string
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 30
}
