---
name: Terraform Module Architecture
description: PTS-24 complete — flat terraform/ replaced with full 11-module structure; remote state still deferred (local backend); module inventory and key notes inside.
type: project
---

PTS-24 (TS-004) is complete. The flat `terraform/` layout (main.tf, ecr.tf, s3.tf, cloudfront.tf, variables.tf, outputs.tf, README.md) has been replaced with a full modular architecture.

**Why:** PTS-20 bootstrapped a minimal flat layout to unblock early work. PTS-24 restructured it to cover the full arc42 deployment view before any service implementation begins.

**How to apply:** All future Terraform work goes into the relevant module under `terraform/modules/<name>/`. The root `main.tf` wires modules together via outputs. Never add resources directly to root `main.tf` — use a module.

## Module inventory (terraform/modules/)

| Module | Purpose |
|--------|---------|
| networking | VPC, subnets, IGW, NAT GWs, route tables, 5 SGs, 8 VPC endpoints |
| iam | ECS task execution role, ECS task role, Lambda execution role, GitHub OIDC role |
| ecr | trading-api and lifecycle-lambda ECR repos + lifecycle policies |
| s3-cloudfront | S3 frontend bucket (OAC) + CloudFront distribution |
| cognito | User Pool (email username) + web client (no secret) |
| dynamodb | pts-websocket-connections table (PAY_PER_REQUEST, TTL, GSI on connectionId) |
| rds | PostgreSQL 16, manage_master_user_password=true, IAM auth, gp3 storage |
| ecs | Fargate cluster, ALB, target group, task definition, service, CPU auto-scaling |
| lambda | Lifecycle Lambda (container image), EventBridge Scheduler role, CW log group |
| api-gateway | REST API + VPC Link + Cognito authorizer + WAF ACL + WebSocket API |
| secrets | Secrets Manager placeholders: db-connection and app-config |

## Key implementation notes

- `aws_region` default changed from `eu-west-1` to `us-east-1` (matches deployment view diagram).
- DB subnets always created as 2 (even in dev) — RDS subnet group requires >= 2 subnets in different AZs.
- `aws_db_instance.manage_master_user_password = true` — password stored in RDS-managed Secrets Manager secret, not Terraform state.
- `aws_ecs_service` lifecycle ignores `[task_definition, desired_count]` — CI/CD owns image updates post initial deploy.
- `aws_lambda_function` lifecycle ignores `[image_uri]` — same pattern for Lambda.
- DynamoDB GSI on `connectionId` added (disconnect event lookup: connectionId -> traderId).
- EventBridge Scheduler `retry_policy.maximum_retry_attempts = 0` (ADR-015: next tick catches up).
- Remote state: still `backend "local"` with TODO comment. Migrate to S3+DynamoDB before prod.
- environments/dev.tfvars: az_count=1, db.t3.micro. environments/prod.tfvars: az_count=2, db.t3.medium.
