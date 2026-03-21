variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, demo)."
  type        = string
}

variable "az_count" {
  description = "Number of AZs in use — drives multi_az when > 1."
  type        = number
}

variable "db_subnet_ids" {
  description = "List of subnet IDs for the RDS DB subnet group. Must contain >= 2 subnets."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID — used to create the RDS security group."
  type        = string
}

variable "ecs_sg_id" {
  description = "Security group ID for ECS tasks — granted ingress on port 5432."
  type        = string
}

variable "lambda_sg_id" {
  description = "Security group ID for the Lifecycle Lambda — granted ingress on port 5432."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class (e.g. db.t3.micro for dev, db.t3.small for demo)."
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "Enable Multi-AZ for the RDS instance."
  type        = bool
  default     = false
}
