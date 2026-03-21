# AWS Infrastructure Reference

## VPC Topology

```
VPC: 10.0.0.0/16  (2 AZs: us-east-1a, us-east-1b)

Public subnets (ALB, NAT Gateway):
  10.0.1.0/24 (AZ-a)   10.0.2.0/24 (AZ-b)

Private-app subnets (ECS Fargate tasks):
  10.0.11.0/24 (AZ-a)  10.0.12.0/24 (AZ-b)

Private-db subnets (RDS):
  10.0.21.0/24 (AZ-a)  10.0.22.0/24 (AZ-b)
```

All outbound traffic from private subnets routes through NAT Gateway in the public subnet.
7 VPC endpoints to keep traffic on the AWS network: ECR API, ECR DKR, S3, Secrets Manager,
CloudWatch Logs, X-Ray, Execute API.

---

## ECS Fargate — Trading API

### Task Definition (Terraform)

```hcl
resource "aws_ecs_task_definition" "trading_api" {
  family                   = "pettrading-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
      { name = "AWS_REGION", value = var.aws_region }
    ]
    secrets = [
      { name = "DB_CONNECTION_STRING", valueFrom = aws_secretsmanager_secret.db.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/pettrading-api"
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
```

### ECS Service

```hcl
resource "aws_ecs_service" "trading_api" {
  name            = "pettrading-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.trading_api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private_app[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}
```

---

## Lambda — Lifecycle Engine

EventBridge Scheduler fires every 60 seconds. Lambda runs the pet tick.

```hcl
resource "aws_lambda_function" "lifecycle" {
  function_name = "pettrading-lifecycle"
  role          = aws_iam_role.lifecycle_lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lifecycle.repository_url}:${var.image_tag}"
  timeout       = 55   # EventBridge fires every 60s; leave 5s margin
  memory_size   = 512

  environment {
    variables = {
      AWS_REGION         = var.aws_region
      SECRETS_ARN        = aws_secretsmanager_secret.db.arn
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private_app[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
}

resource "aws_scheduler_schedule" "lifecycle_tick" {
  name = "pettrading-lifecycle-tick"
  flexible_time_window { mode = "OFF" }
  schedule_expression = "rate(1 minute)"
  target {
    arn      = aws_lambda_function.lifecycle.arn
    role_arn = aws_iam_role.scheduler_invoke_lambda.arn
  }
}
```

---

## API Gateway — REST API + WebSocket API

### REST API

```hcl
resource "aws_api_gateway_rest_api" "trading" {
  name = "pettrading-rest"
  endpoint_configuration { types = ["REGIONAL"] }
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.trading.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.main.arn]
}
```

Attach WAF WebACL to the REST API stage. Apply throttling via usage plan:
`burst_limit = 1000`, `rate_limit = 500`.

### WebSocket API

```hcl
resource "aws_apigatewayv2_api" "ws" {
  name                       = "pettrading-ws"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = "$connect"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}
```

Trading API stores `traderId → connectionId` in DynamoDB on `$connect`.

---

## Cognito User Pool

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "pettrading-users"

  password_policy {
    minimum_length    = 12
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  auto_verified_attributes = ["email"]

  schema {
    name            = "traderId"
    attribute_data_type = "String"
    mutable         = false
  }
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "pettrading-spa"
  user_pool_id = aws_cognito_user_pool.main.id
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
  prevent_user_existence_errors = "ENABLED"
}
```

JWT issuer: `https://cognito-idp.{region}.amazonaws.com/{userPoolId}`
JWKS: `{issuer}/.well-known/jwks.json`

---

## RDS PostgreSQL 16

```hcl
resource "aws_db_instance" "postgres" {
  identifier             = "pettrading-db"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = "db.t4g.medium"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_encrypted      = true
  multi_az               = true
  db_name                = "pettrading"
  username               = "pettrading_admin"
  manage_master_user_password = true   # Secrets Manager rotation
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  backup_retention_period = 7
  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection    = true
}
```

Security group: only port 5432 from ECS task SG and Lambda SG.

---

## Secrets Manager

Store DB credentials and Cognito client secret. Never store in env vars or config files.

```hcl
resource "aws_secretsmanager_secret" "db" {
  name = "pettrading/db"
  recovery_window_in_days = 7
}
```

Access from .NET:

```csharp
var secretJson = await secretsManager.GetSecretValueAsync(
    new GetSecretValueRequest { SecretId = "pettrading/db" });
var secret = JsonSerializer.Deserialize<DbSecret>(secretJson.SecretString);
```

---

## DynamoDB — WebSocket Connection Tracking

```hcl
resource "aws_dynamodb_table" "ws_connections" {
  name         = "pettrading-ws-connections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "traderId"

  attribute {
    name = "traderId"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
```

On `$connect`: write `{ traderId, connectionId, ttl: NOW + 24h }`.
On `$disconnect`: delete item by `connectionId` (GSI on `connectionId` recommended).
On `GoneException` (410) when posting: delete stale item.

---

## ECR — Container Images

```hcl
resource "aws_ecr_repository" "api" {
  name                 = "pettrading-api"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}
```

Push images from GitHub Actions using OIDC (no static IAM keys):

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/github-actions-deploy
    aws-region: us-east-1
- uses: aws-actions/amazon-ecr-login@v2
- run: docker build -t $ECR_REGISTRY/pettrading-api:${{ github.sha }} .
- run: docker push $ECR_REGISTRY/pettrading-api:${{ github.sha }}
```

---

## CloudFront + S3 — React SPA

```hcl
resource "aws_s3_bucket" "spa" {
  bucket = "pettrading-spa-${var.environment}"
}

resource "aws_cloudfront_distribution" "spa" {
  origin {
    domain_name              = aws_s3_bucket.spa.bucket_regional_domain_name
    origin_id                = "spa-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.spa.id
  }
  default_root_object = "index.html"
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"  # SPA client-side routing
  }
}
```

---

## IAM Roles — Least Privilege

### ECS Task Role (what the app can DO)

```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "xray:PutTraceSegments",
    "xray:PutTelemetryRecords",
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:DeleteItem",
    "execute-api:ManageConnections"
  ],
  "Resource": ["<specific ARNs only>"]
}
```

### Lambda Execution Role

```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "xray:PutTraceSegments",
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents",
    "ec2:CreateNetworkInterface",
    "ec2:DescribeNetworkInterfaces",
    "ec2:DeleteNetworkInterface"
  ],
  "Resource": ["<specific ARNs only>"]
}
```

Never use `*` in Resource for production roles.

---

## WAF on API Gateway

Enable the AWS Managed Rules common rule set and known bad inputs rule set:

```hcl
resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_api_gateway_stage.v1.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}
```

Add a rate-based rule to block IPs exceeding 2000 requests per 5-minute window.
