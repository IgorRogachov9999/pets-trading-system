variable "project_name" {
  description = "Project name used in S3 bucket naming."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}
