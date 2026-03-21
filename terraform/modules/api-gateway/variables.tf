variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, demo)."
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB used for the VPC Link integration."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB — used as the integration URI for the REST API."
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN — used by the REST API Cognito authorizer."
  type        = string
}
