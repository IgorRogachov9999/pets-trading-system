variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, demo)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to deploy into."
  type        = number
}

variable "az_names" {
  description = "List of AZ names to use (e.g. [\"us-east-1a\", \"us-east-1b\"])."
  type        = list(string)
}
