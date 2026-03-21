# Security & Networking Reference — Pets Trading System

## Table of Contents
1. [VPC & Subnet Architecture](#1-vpc--subnet-architecture)
2. [Security Groups](#2-security-groups)
3. [IAM Design Principles](#3-iam-design-principles)
4. [Secrets Manager Patterns](#4-secrets-manager-patterns)
5. [WAF Configuration](#5-waf-configuration)
6. [TLS & Certificate Management](#6-tls--certificate-management)
7. [Security Checklist](#7-security-checklist)

---

## 1. VPC & Subnet Architecture

```
VPC: 10.0.0.0/16 (us-east-1)
│
├── AZ us-east-1a
│   ├── Public    10.0.0.0/24   ← ALB, NAT Gateway
│   ├── Private-app 10.0.2.0/24  ← ECS tasks, Lambda
│   └── Private-db  10.0.4.0/24  ← RDS primary
│
└── AZ us-east-1b
    ├── Public    10.0.1.0/24   ← ALB, NAT Gateway
    ├── Private-app 10.0.3.0/24  ← ECS tasks, Lambda
    └── Private-db  10.0.5.0/24  ← RDS standby (Multi-AZ)

VPC Endpoints (all in private-app subnets, sg=vpc-endpoints-sg):
  Interface: ecr.api, ecr.dkr, secretsmanager, logs, xray, execute-api
  Gateway:   s3
```

**Routing rules:**
- Public subnets → Internet Gateway (for ALB inbound, NAT GW outbound)
- Private-app → NAT Gateway (for outbound HTTPS only; VPC endpoints preferred)
- Private-db → no internet route (isolated, RDS only)

```hcl
# Route: private-app subnets use NAT for internet, VPC endpoints for AWS services
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main["a"].id
  }
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id
  # No 0.0.0.0/0 route — DB subnets are fully isolated
}
```

---

## 2. Security Groups

```hcl
# ALB — accepts HTTPS from internet
resource "aws_security_group" "alb" {
  name   = "petstrading-alb-${var.environment}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP redirect to HTTPS"
  }
  egress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
}

# ECS tasks — accepts only from ALB on port 8080
resource "aws_security_group" "ecs_tasks" {
  name   = "petstrading-ecs-${var.environment}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for VPC endpoints and internet (via NAT)"
  }
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }
}

# RDS — accepts only from ECS and Lambda on 5432
resource "aws_security_group" "rds" {
  name   = "petstrading-rds-${var.environment}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id, aws_security_group.lambda.id]
  }
  # No egress needed (RDS is server only)
}

# Lambda lifecycle function
resource "aws_security_group" "lambda" {
  name   = "petstrading-lambda-${var.environment}"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }
}

# VPC Endpoints — accepts HTTPS from private-app subnets
resource "aws_security_group" "vpc_endpoints" {
  name   = "petstrading-vpce-${var.environment}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24", "10.0.3.0/24"]
  }
}
```

---

## 3. IAM Design Principles

**Principle of least privilege** — every role has only the permissions it actually needs. Never use `"Resource": "*"` for data-plane actions.

**Role inventory:**

| Role | Who Assumes | Key Permissions |
|---|---|---|
| `petstrading-ecs-execution-*` | ECS (pull images, write logs) | ECR pull, CloudWatch write, SecretsManager read |
| `petstrading-ecs-task-*` | Trading API container | DynamoDB RW (connections table), execute-api:ManageConnections, SecretsManager read (db secret only), X-Ray write |
| `petstrading-lambda-lifecycle-*` | Lifecycle Lambda | SecretsManager read (db secret only), VPC execution, X-Ray write |
| `petstrading-github-actions` | GitHub Actions OIDC | ECR push (specific repos), ECS update-service, Lambda update-code, S3 sync (frontend bucket), CloudFront invalidate |
| `petstrading-scheduler-*` | EventBridge Scheduler | lambda:InvokeFunction (lifecycle function only) |

**ECS Execution Role** (minimum required):
```hcl
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional: read the specific secret for task definition `secrets:` injection
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_secret_arn]
    }]
  })
}
```

**Never use:**
- `"Action": "iam:*"` in task/Lambda roles
- `"Resource": "*"` for DynamoDB, SecretsManager, or execute-api actions
- Inline policies on users — use roles only

---

## 4. Secrets Manager Patterns

**Secret naming convention:**
```
petstrading/<environment>/db          → RDS credentials + connection string
petstrading/<environment>/cognito     → Cognito client secret (if needed)
```

**Rotation:** DB password rotates every 30 days via Lambda rotation function. The application must tolerate a brief window where the old and new password coexist — Npgsql handles reconnect on authentication failure.

**Accessing secrets in .NET:**
```csharp
// At startup — load from Secrets Manager into IConfiguration
builder.Configuration.AddSecretsManager(configurator: options =>
{
    options.SecretFilter = secret =>
        secret.Name.StartsWith($"petstrading/{environment}/");
    options.KeyGenerator = (secret, key) =>
        key.Replace($"petstrading/{environment}/", "")
           .Replace("/", ":");  // maps to nested config keys
});
```

**Never:**
- Store secrets in environment variables (`Environment.GetEnvironmentVariable`)
- Log secret values (even partially)
- Commit secrets to git
- Store secrets in Terraform state in plaintext — use `sensitive = true` on all secret variables

---

## 5. WAF Configuration

WAF is attached to both the REST API Gateway and the CloudFront distribution.

**Rules applied:**
1. `AWSManagedRulesCommonRuleSet` — blocks OWASP Top 10 (SQLi, XSS, RCE, etc.)
2. `AWSManagedRulesAmazonIpReputationList` — blocks known malicious IPs
3. `RateLimitPerIP` — blocks IPs making > 2000 req/5min

```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "petstrading-waf-${var.environment}"
  scope = "REGIONAL"
  default_action { allow {} }

  rule {
    name = "AWSManagedRulesCommonRuleSet"; priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement { vendor_name = "AWS"; name = "AWSManagedRulesCommonRuleSet" }
    }
    visibility_config { cloudwatch_metrics_enabled = true; metric_name = "CommonRuleSet"; sampled_requests_enabled = true }
  }

  rule {
    name = "IPReputation"; priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement { vendor_name = "AWS"; name = "AWSManagedRulesAmazonIpReputationList" }
    }
    visibility_config { cloudwatch_metrics_enabled = true; metric_name = "IPReputation"; sampled_requests_enabled = true }
  }

  rule {
    name = "RateLimitPerIP"; priority = 3
    action { block {} }
    statement {
      rate_based_statement { limit = 2000; aggregate_key_type = "IP" }
    }
    visibility_config { cloudwatch_metrics_enabled = true; metric_name = "RateLimit"; sampled_requests_enabled = true }
  }

  visibility_config { cloudwatch_metrics_enabled = true; metric_name = "petstrading"; sampled_requests_enabled = true }
}
```

---

## 6. TLS & Certificate Management

- ALB listener on port 443 with ACM certificate for the API domain
- CloudFront uses ACM certificate for the frontend domain (must be in `us-east-1`)
- API Gateway REST uses custom domain with regional ACM certificate
- All HTTP traffic (port 80) redirects to HTTPS

```hcl
resource "aws_acm_certificate" "api" {
  domain_name       = "api.petstrading.example.com"
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}

# CloudFront certificate must be in us-east-1
resource "aws_acm_certificate" "frontend" {
  provider          = aws.us_east_1   # alias provider
  domain_name       = "app.petstrading.example.com"
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}
```

---

## 7. Security Checklist

Before any infrastructure change reaches production, verify:

**Network:**
- [ ] No security group allows inbound 0.0.0.0/0 except ALB (443/80)
- [ ] RDS security group accepts only from ECS and Lambda SGs
- [ ] All 7 VPC endpoints are active (no traffic leaves VPC for AWS service calls)
- [ ] Private-db subnets have no route to internet

**IAM:**
- [ ] No wildcard actions on data-plane resources
- [ ] OIDC trust policy scoped to specific repo + ref
- [ ] ECS task role has no `iam:*` or `ec2:*` permissions
- [ ] Lambda execution role has no console-level permissions

**Secrets:**
- [ ] No secrets in Terraform code or state (use `sensitive` + SecretsManager data source)
- [ ] No secrets in GitHub Actions secrets (use OIDC + SecretsManager)
- [ ] Rotation configured for DB password

**Containers:**
- [ ] All images immutable-tagged in ECR
- [ ] ECR scan on push enabled; no CRITICAL vulnerabilities deployed
- [ ] Container runs as non-root user

**Application:**
- [ ] CORS configured for CloudFront origin only
- [ ] JWT validation in API Gateway (Cognito authorizer) + application layer
- [ ] WAF attached to API Gateway and CloudFront
