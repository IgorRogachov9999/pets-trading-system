variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, demo). Not used in resource names — ECR is shared."
  type        = string
  default     = ""
}
