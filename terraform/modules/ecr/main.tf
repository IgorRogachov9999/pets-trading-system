# ==============================================================================
# modules/ecr/main.tf
# ECR repositories for Trading API and Lifecycle Lambda container images.
# Lifecycle policy: keep last 10 tagged images, expire untagged after 1 day.
# ==============================================================================

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
    Name = "${var.project_name}-ecr-trading-api"
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
    Name = "${var.project_name}-ecr-lifecycle-lambda"
  }
}

resource "aws_ecr_lifecycle_policy" "lifecycle_lambda" {
  repository = aws_ecr_repository.lifecycle_lambda.name
  policy     = local.lifecycle_policy
}
