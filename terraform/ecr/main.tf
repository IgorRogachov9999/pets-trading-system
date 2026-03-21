# ==============================================================================
# ecr/main.tf
# Standalone ECR root configuration — shared across all environments.
# ECR repositories have no environment suffix because dev and demo share the
# same container images. This configuration has its own state file:
#   pts/ecr/terraform.tfstate
# Run this BEFORE the per-environment Terraform in CI/CD pipelines.
# ==============================================================================

provider "aws" {
  region = var.aws_region
}

locals {
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_repository" "trading_api" {
  name                 = "${var.project_name}-trading-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "${var.project_name}-ecr-trading-api"
    Project = var.project_name
  }
}

resource "aws_ecr_lifecycle_policy" "trading_api" {
  repository = aws_ecr_repository.trading_api.name
  policy     = local.lifecycle_policy
}

resource "aws_ecr_repository" "lifecycle_lambda" {
  name                 = "${var.project_name}-lifecycle-lambda"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "${var.project_name}-ecr-lifecycle-lambda"
    Project = var.project_name
  }
}

resource "aws_ecr_lifecycle_policy" "lifecycle_lambda" {
  repository = aws_ecr_repository.lifecycle_lambda.name
  policy     = local.lifecycle_policy
}
