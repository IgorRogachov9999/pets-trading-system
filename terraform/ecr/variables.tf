variable "project_name" {
  description = "Project name used in ECR repository naming."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}
