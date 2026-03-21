# Terraform AWS Reference — Pets Trading System

## Table of Contents
1. [Backend & State](#1-backend--state)
2. [Provider Setup](#2-provider-setup)
3. [VPC Module](#3-vpc-module)
4. [ECR Repositories](#4-ecr-repositories)
5. [ECS Fargate (Trading API)](#5-ecs-fargate-trading-api)
6. [RDS PostgreSQL](#6-rds-postgresql)
7. [Lambda + EventBridge (Lifecycle Engine)](#7-lambda--eventbridge-lifecycle-engine)
8. [API Gateway REST + WebSocket](#8-api-gateway-rest--websocket)
9. [DynamoDB (WebSocket connections)](#9-dynamodb-websocket-connections)
10. [S3 + CloudFront (Frontend)](#10-s3--cloudfront-frontend)
11. [Cognito](#11-cognito)
12. [WAF](#12-waf)
13. [Secrets Manager](#13-secrets-manager)
14. [IAM — OIDC for GitHub Actions](#14-iam--oidc-for-github-actions)
15. [CloudWatch Alarms](#15-cloudwatch-alarms)
16. [Naming & Tagging](#16-naming--tagging)

---

## 1. Backend & State

```hcl
# terraform/environments/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "petstrading-tfstate-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "petstrading-tflock"
  }
}

# Create the state bucket and lock table (one-time, in global/)
resource "aws_s3_bucket" "tfstate" {
  bucket = "petstrading-tfstate-${var.environment}"
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_dynamodb_table" "tflock" {
  name         = "petstrading-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute { name = "LockID"; type = "S" }
}
```

---

## 2. Provider Setup

```hcl
# terraform/environments/prod/versions.tf
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "petstrading"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

---

## 3. VPC Module

```hcl
# terraform/modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr   # 10.0.0.0/16
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "public" {
  for_each          = { a = "10.0.0.0/24", b = "10.0.1.0/24" }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = "${var.aws_region}${each.key}"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_app" {
  for_each          = { a = "10.0.2.0/24", b = "10.0.3.0/24" }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = "${var.aws_region}${each.key}"
}

resource "aws_subnet" "private_db" {
  for_each          = { a = "10.0.4.0/24", b = "10.0.5.0/24" }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = "${var.aws_region}${each.key}"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" { for_each = { a = 0, b = 1 }; domain = "vpc" }

resource "aws_nat_gateway" "main" {
  for_each      = { a = aws_subnet.public["a"].id, b = aws_subnet.public["b"].id }
  subnet_id     = each.value
  allocation_id = aws_eip.nat[each.key].id
  depends_on    = [aws_internet_gateway.main]
}

# 7 VPC Endpoints (all Interface type except S3 = Gateway)
locals {
  interface_endpoints = toset([
    "ecr.api", "ecr.dkr", "secretsmanager",
    "logs", "xray", "execute-api"
  ])
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoints
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private_app)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_app.id]
}
```

---

## 4. ECR Repositories

```hcl
# terraform/global/ecr/main.tf
resource "aws_ecr_repository" "trading_api" {
  name                 = "petstrading/trading-api"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "lifecycle_lambda" {
  name                 = "petstrading/lifecycle-lambda"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_lifecycle_policy" "trading_api" {
  repository = aws_ecr_repository.trading_api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 production images"
      selection    = { tagStatus = "tagged"; tagPrefixList = ["v"]; countType = "imageCountMoreThan"; countNumber = 10 }
      action       = { type = "expire" }
    }, {
      rulePriority = 2
      description  = "Expire untagged after 7 days"
      selection    = { tagStatus = "untagged"; countType = "sinceImagePushed"; countUnit = "days"; countNumber = 7 }
      action       = { type = "expire" }
    }]
  })
}
```

---

## 5. ECS Fargate (Trading API)

```hcl
# terraform/modules/ecs/main.tf
resource "aws_ecs_cluster" "main" {
  name = "petstrading-${var.environment}"
  setting { name = "containerInsights"; value = "enabled" }
}

resource "aws_ecs_task_definition" "trading_api" {
  family                   = "petstrading-trading-api-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "trading-api"
    image     = "${var.ecr_repo_url}:${var.image_tag}"
    essential = true
    portMappings = [{ containerPort = 8080; protocol = "tcp" }]
    environment = [{ name = "ASPNETCORE_ENVIRONMENT"; value = var.environment }]
    secrets = [
      { name = "ConnectionStrings__Postgres"; valueFrom = "${var.db_secret_arn}:connectionString::" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/petstrading-trading-api"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

resource "aws_ecs_service" "trading_api" {
  name            = "trading-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.trading_api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.trading_api.arn
    container_name   = "trading-api"
    container_port   = 8080
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  lifecycle { ignore_changes = [task_definition] }   # CI manages image updates
}

# ECS Task IAM Role — least privilege
resource "aws_iam_role" "ecs_task" {
  name = "petstrading-ecs-task-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Principal = { Service = "ecs-tasks.amazonaws.com" }; Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "ecs-task-policy"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"; Action = ["secretsmanager:GetSecretValue"]; Resource = [var.db_secret_arn] },
      { Effect = "Allow"; Action = ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:DeleteItem","dynamodb:Scan"]
        Resource = [var.connections_table_arn] },
      { Effect = "Allow"; Action = ["execute-api:ManageConnections"]
        Resource = ["arn:aws:execute-api:${var.aws_region}:*:${var.websocket_api_id}/*"] },
      { Effect = "Allow"; Action = ["xray:PutTraceSegments","xray:PutTelemetryRecords"]; Resource = "*" }
    ]
  })
}
```

---

## 6. RDS PostgreSQL

```hcl
# terraform/modules/rds/main.tf
resource "aws_db_subnet_group" "main" {
  name       = "petstrading-${var.environment}"
  subnet_ids = var.private_db_subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier             = "petstrading-${var.environment}"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = var.environment == "prod" ? "db.t3.small" : "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = true
  multi_az               = var.environment == "prod"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_name                = "petstrading"
  username               = "petstrading"
  password               = random_password.db.result
  backup_retention_period = 7
  skip_final_snapshot    = false
  final_snapshot_identifier = "petstrading-${var.environment}-final"
  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection    = var.environment == "prod"

  lifecycle { prevent_destroy = true }
}

# Store DB credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db" {
  name = "petstrading/${var.environment}/db"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username         = aws_db_instance.postgres.username
    password         = random_password.db.result
    host             = aws_db_instance.postgres.address
    port             = aws_db_instance.postgres.port
    dbname           = aws_db_instance.postgres.db_name
    connectionString = "Host=${aws_db_instance.postgres.address};Database=petstrading;Username=${aws_db_instance.postgres.username};Password=${random_password.db.result}"
  })
}
```

---

## 7. Lambda + EventBridge (Lifecycle Engine)

```hcl
# terraform/modules/lambda/main.tf
resource "aws_lambda_function" "lifecycle" {
  function_name = "petstrading-lifecycle-${var.environment}"
  package_type  = "Image"
  image_uri     = "${var.ecr_lifecycle_repo_url}:${var.lambda_image_tag}"
  role          = aws_iam_role.lambda.arn
  timeout       = 30
  memory_size   = 256

  vpc_config {
    subnet_ids         = var.private_app_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
      ENVIRONMENT   = var.environment
    }
  }

  tracing_config { mode = "Active" }   # X-Ray
}

resource "aws_scheduler_schedule" "lifecycle_tick" {
  name                = "petstrading-lifecycle-tick-${var.environment}"
  schedule_expression = "rate(1 minute)"

  flexible_time_window { mode = "OFF" }

  target {
    arn      = aws_lambda_function.lifecycle.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}

resource "aws_iam_role" "lambda" {
  name = "petstrading-lambda-lifecycle-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Principal = { Service = "lambda.amazonaws.com" }; Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"; Action = ["secretsmanager:GetSecretValue"]; Resource = [var.db_secret_arn] },
      { Effect = "Allow"; Action = ["xray:PutTraceSegments","xray:PutTelemetryRecords"]; Resource = "*" }
    ]
  })
}
```

---

## 8. API Gateway REST + WebSocket

```hcl
# REST API
resource "aws_api_gateway_rest_api" "main" {
  name = "petstrading-${var.environment}"
  endpoint_configuration { types = ["REGIONAL"] }
}

# WAF association (see WAF module)
resource "aws_wafv2_web_acl_association" "api_gw" {
  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = var.waf_acl_arn
}

# WebSocket API
resource "aws_apigatewayv2_api" "websocket" {
  name                       = "petstrading-ws-${var.environment}"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect.id}"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.default.id}"
}
```

---

## 9. DynamoDB (WebSocket connections)

```hcl
resource "aws_dynamodb_table" "connections" {
  name         = "petstrading-connections-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "traderId"

  attribute { name = "traderId"; type = "S" }

  ttl { attribute_name = "ttl"; enabled = true }

  point_in_time_recovery { enabled = true }
}
```

---

## 10. S3 + CloudFront (Frontend)

```hcl
resource "aws_s3_bucket" "frontend" {
  bucket = "petstrading-frontend-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values { query_string = false; cookies { forward = "none" } }
    # Cache 1 year for hashed assets, 0 for index.html (set via S3 object metadata in CI)
  }

  custom_error_response {
    error_code            = 404
    response_page_path    = "/index.html"   # SPA routing
    response_code         = 200
  }

  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }

  web_acl_id = var.waf_acl_arn  # attach WAF
  enabled    = true
  price_class = "PriceClass_100"
}
```

---

## 11. Cognito

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "petstrading-${var.environment}"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_numbers   = true
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "petstrading-spa-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = [var.cloudfront_url]
  logout_urls                          = [var.cloudfront_url]
  supported_identity_providers         = ["COGNITO"]

  access_token_validity  = 60    # minutes
  refresh_token_validity = 30    # days
  token_validity_units { access_token = "minutes"; refresh_token = "days" }
}
```

---

## 12. WAF

```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "petstrading-waf-${var.environment}"
  scope = "REGIONAL"

  default_action { allow {} }

  # AWS Managed Rules
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement { vendor_name = "AWS"; name = "AWSManagedRulesCommonRuleSet" }
    }
    visibility_config { cloudwatch_metrics_enabled = true; metric_name = "CommonRuleSet"; sampled_requests_enabled = true }
  }

  # Rate limiting per IP
  rule {
    name     = "RateLimitPerIP"
    priority = 2
    action { block {} }
    statement {
      rate_based_statement { limit = 2000; aggregate_key_type = "IP" }
    }
    visibility_config { cloudwatch_metrics_enabled = true; metric_name = "RateLimit"; sampled_requests_enabled = true }
  }

  visibility_config { cloudwatch_metrics_enabled = true; metric_name = "petstrading-waf"; sampled_requests_enabled = true }
}
```

---

## 13. Secrets Manager

```hcl
# Reference secrets from application code via ECS task secrets or Lambda env
# Rotation Lambda for DB password
resource "aws_secretsmanager_secret_rotation" "db" {
  secret_id           = aws_secretsmanager_secret.db.id
  rotation_lambda_arn = var.rotation_lambda_arn
  rotation_rules      { automatically_after_days = 30 }
}
```

---

## 14. IAM — OIDC for GitHub Actions

```hcl
# terraform/global/iam-oidc/main.tf
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "github_actions" {
  name = "petstrading-github-actions"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = { "token.actions.githubusercontent.com:sub" = "repo:your-org/pets-trading-system:*" }
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions" {
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"; Action = ["ecr:GetAuthorizationToken"]; Resource = "*" },
      { Effect = "Allow"; Action = ["ecr:BatchCheckLayerAvailability","ecr:PutImage","ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload"]
        Resource = [var.trading_api_ecr_arn, var.lifecycle_lambda_ecr_arn] },
      { Effect = "Allow"; Action = ["ecs:UpdateService","ecs:DescribeServices"]
        Resource = [var.ecs_service_arn] },
      { Effect = "Allow"; Action = ["lambda:UpdateFunctionCode"]
        Resource = [var.lifecycle_lambda_arn] },
      { Effect = "Allow"; Action = ["s3:PutObject","s3:DeleteObject","s3:ListBucket"]
        Resource = [var.frontend_bucket_arn, "${var.frontend_bucket_arn}/*"] },
      { Effect = "Allow"; Action = ["cloudfront:CreateInvalidation"]
        Resource = [var.cloudfront_distribution_arn] }
    ]
  })
}
```

---

## 15. CloudWatch Alarms

```hcl
# terraform/modules/monitoring/alarms.tf
locals {
  alarms = {
    api_5xx = {
      metric      = "5XXError"; namespace = "AWS/ApiGateway"
      threshold   = 1; comparison = "GreaterThanThreshold"
      description = "API 5xx error rate > 1%"
    }
    api_latency_p99 = {
      metric      = "Latency"; namespace = "AWS/ApiGateway"
      threshold   = 1000; comparison = "GreaterThanThreshold"
      description = "API P99 latency > 1s"
    }
    lambda_errors = {
      metric      = "Errors"; namespace = "AWS/Lambda"
      threshold   = 0; comparison = "GreaterThanThreshold"
      description = "Lambda lifecycle errors"
    }
    rds_cpu = {
      metric      = "CPUUtilization"; namespace = "AWS/RDS"
      threshold   = 80; comparison = "GreaterThanThreshold"
      description = "RDS CPU > 80%"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "alarms" {
  for_each            = local.alarms
  alarm_name          = "petstrading-${var.environment}-${each.key}"
  alarm_description   = each.value.description
  metric_name         = each.value.metric
  namespace           = each.value.namespace
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison
  alarm_actions       = [var.sns_alert_topic_arn]
  ok_actions          = [var.sns_alert_topic_arn]
}
```

---

## 16. Naming & Tagging

**Resource naming:** `petstrading-{environment}-{resource-type}` (e.g., `petstrading-prod-ecs-cluster`)

**Required tags** (applied via provider `default_tags`):
```hcl
Project     = "petstrading"
Environment = var.environment   # "dev" or "prod"
ManagedBy   = "terraform"
```

**Module versioning:** pin all modules with `~>` to avoid unexpected upgrades.

**Variables convention:** snake_case names, boolean variables start with `enable_` or `is_`, list variables use plural names.
