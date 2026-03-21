# ==============================================================================
# variables.tf — Global input variables
# pets-trading-system
# ==============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming and tagging."
  type        = string
  default     = "pts"
}

variable "environment" {
  description = "Deployment environment (dev, demo)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "demo"], var.environment)
    error_message = "environment must be 'dev' or 'demo'."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to deploy into. Use 1 for dev, 2 for demo."
  type        = number
  default     = 1

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 2
    error_message = "az_count must be 1 or 2."
  }
}

variable "db_instance_class" {
  description = "RDS instance class. Use db.t3.micro for dev, db.t3.small for demo."
  type        = string
  default     = "db.t3.micro"
}

variable "ecs_cpu" {
  description = "ECS task CPU units. Use 256 for dev, 512 for demo."
  type        = string
  default     = "512"
}

variable "ecs_memory" {
  description = "ECS task memory in MiB. Use 512 for dev, 1024 for demo."
  type        = string
  default     = "1024"
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days. Use 30 for dev, 90 for demo."
  type        = number
  default     = 30
}
