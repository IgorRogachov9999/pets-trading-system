# ==============================================================================
# modules/lambda/main.tf
# Lifecycle Lambda — .NET 10 container image, VPC-attached, EventBridge Scheduler.
# Runs every 60 seconds to apply health/desirability variance and age updates.
# ADR-015: Lambda replaces ECS singleton.
# ==============================================================================

# ------------------------------------------------------------------------------
# CloudWatch Log Group (pre-created so retention is enforced from day 1)
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lifecycle_lambda" {
  name              = "/${var.environment}/lifecycle-engine"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-logs-lifecycle-lambda"
  }
}

# ------------------------------------------------------------------------------
# Lambda Function
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "lifecycle" {
  function_name = "${var.project_name}-${var.environment}-lifecycle-lambda"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"

  # image_uri is updated by CI/CD after ECR push — initial deploy uses placeholder.
  # lifecycle.ignore_changes prevents Terraform from reverting CI/CD updates.
  image_uri = "${var.lifecycle_lambda_image_url}:latest"

  memory_size = 512
  timeout     = 60

  vpc_config {
    subnet_ids         = var.private_app_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST = var.db_endpoint
      DB_PORT = "5432"
      DB_NAME = var.db_name
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.lifecycle_lambda]

  lifecycle {
    ignore_changes = [image_uri]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-lifecycle"
  }
}

# ------------------------------------------------------------------------------
# EventBridge Scheduler — triggers Lambda every 60 seconds
# ADR-015: no retries; next scheduled invocation catches up on failure.
# ------------------------------------------------------------------------------
resource "aws_scheduler_schedule" "lifecycle" {
  name       = "${var.project_name}-${var.environment}-lifecycle-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(1 minute)"

  target {
    arn      = aws_lambda_function.lifecycle.arn
    role_arn = aws_iam_role.scheduler.arn

    retry_policy {
      maximum_retry_attempts = 0
    }
  }
}

# IAM role for EventBridge Scheduler to invoke Lambda
resource "aws_iam_role" "scheduler" {
  name = "${var.project_name}-${var.environment}-role-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "scheduler.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-role-scheduler"
  }
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  name = "invoke-lifecycle-lambda"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.lifecycle.arn
      }
    ]
  })
}
