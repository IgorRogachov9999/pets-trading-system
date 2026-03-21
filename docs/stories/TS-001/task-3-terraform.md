# Task 3: Infrastructure — Terraform Rework (PTS-20)

**Jira**: [PTS-20](https://igorrogachov9999.atlassian.net/browse/PTS-20)
**Story**: [TS-001](./story.md)
**Label**: `devops`
**Status**: In Review

---

## Summary of Changes

This task reworked the Terraform configuration from an initial scaffolding to a production-aligned
structure. The changes cover eight areas:

---

### 1. ECR — Environment Removed from Repo Names

ECR is a shared resource serving all environments. Repo names no longer carry an environment suffix.

- `${var.project_name}-trading-api` (was `${var.project_name}-${var.environment}-trading-api`)
- `${var.project_name}-lifecycle-lambda` (was `${var.project_name}-${var.environment}-lifecycle-lambda`)
- Environment tag removed from ECR resources (covered by provider `default_tags`)

**Files changed**: `terraform/modules/ecr/main.tf`, `terraform/modules/ecr/variables.tf`

---

### 2. IAM Module Dissolved — IAM Distributed to Owning Modules

The monolithic `terraform/modules/iam/` module (415 lines) has been deleted. IAM roles now live
beside the resources they serve:

| New file | Contains |
|---|---|
| `terraform/modules/ecs/iam.tf` | ECS task execution role, ECS task role with DynamoDB/API GW/CW/X-Ray/SM permissions |
| `terraform/modules/lambda/iam.tf` | Lambda execution role with VPC access, RDS IAM auth, CW/X-Ray/SM permissions |
| `terraform/iam.tf` | GitHub Actions OIDC provider + role (cross-cutting CI/CD concern) |

ECS and Lambda modules now self-contain their IAM roles. `module "iam"` removed from `main.tf`.
`ecs_task_execution_role_arn` and `ecs_task_role_arn` added to ECS outputs; `lambda_execution_role_arn`
added to Lambda outputs.

**Files deleted**: `terraform/modules/iam/` (entire directory)
**Files created**: `terraform/modules/ecs/iam.tf`, `terraform/modules/lambda/iam.tf`, `terraform/iam.tf`
**Files changed**: `terraform/main.tf`, `terraform/modules/ecs/outputs.tf`, `terraform/modules/lambda/outputs.tf`, `terraform/outputs.tf`

---

### 3. Log Group Naming — New Pattern `/{environment}/{service}`

Old pattern was `/ecs/${project}-${env}-trading-api` and `/lambda/${project}-${env}-lifecycle-engine`.

New pattern:
- `/${var.environment}/trading-api`
- `/${var.environment}/lifecycle-engine`

IAM policies in `ecs/iam.tf` and `lambda/iam.tf` reference the new log group ARN pattern.
Root `locals` for `ecs_log_group_name` and `lambda_log_group_name` removed from `main.tf`.

**Files changed**: `terraform/modules/ecs/main.tf`, `terraform/modules/lambda/main.tf`,
`terraform/modules/ecs/iam.tf`, `terraform/modules/lambda/iam.tf`

---

### 4. Default Tags — Added `Terraform = "true"` Tag

Provider `default_tags` block updated:

```hcl
default_tags {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Terraform   = "true"
    ManagedBy   = "terraform"
  }
}
```

Redundant per-resource `Project` and `Environment` tags kept only as `Name` tags (useful in AWS
console); they are no longer duplicating the provider-level tags.

**Files changed**: `terraform/main.tf`

---

### 5. Externalized Config to Environment tfvars

New variables added to root `variables.tf`:
- `ecs_cpu` (string, default "512")
- `ecs_memory` (string, default "1024")
- `log_retention_days` (number, default 30)

New variables added to `modules/ecs/variables.tf`:
- `ecs_cpu`, `ecs_memory`, `log_retention_days`, `dynamodb_table_name`, `aws_region`

New variable added to `modules/lambda/variables.tf`:
- `log_retention_days`

Environment-specific values in tfvars:

| Variable | dev | demo |
|---|---|---|
| `ecs_cpu` | "256" | "512" |
| `ecs_memory` | "512" | "1024" |
| `log_retention_days` | 30 | 90 |
| `az_count` | 1 | 2 |
| `db_instance_class` | db.t3.micro | db.t3.small |

**Files created**: `terraform/environments/demo.tfvars`
**Files changed**: `terraform/environments/dev.tfvars`, `terraform/variables.tf`,
`terraform/modules/ecs/variables.tf`, `terraform/modules/lambda/variables.tf`
**Files deleted**: `terraform/environments/prod.tfvars`

---

### 6. Networking Module Split into 5 Focused Files

`terraform/modules/networking/main.tf` (446 lines) deleted. Replaced by:

| File | Contents |
|---|---|
| `vpc.tf` | VPC, Internet Gateway, EIPs, NAT Gateways |
| `subnets.tf` | Public, private-app, private-db subnet resources; CIDR locals |
| `routing.tf` | Route tables, routes, route table associations |
| `security_groups.tf` | All security groups and security group rules |
| `endpoints.tf` | All 7 VPC endpoints (2 Gateway + 6 Interface) |

`variables.tf` and `outputs.tf` unchanged.

**Files deleted**: `terraform/modules/networking/main.tf`
**Files created**: `vpc.tf`, `subnets.tf`, `routing.tf`, `security_groups.tf`, `endpoints.tf`
(all under `terraform/modules/networking/`)

---

### 7. General Configurability

- CloudWatch log group `retention_in_days` hardcodes (14 in ECS, 7 in Lambda) replaced with
  `var.log_retention_days` in both modules.
- `aws_region` hardcode (`"us-east-1"`) in ECS task definition log configuration replaced with
  `var.aws_region`.
- RDS `backup_retention_period` (7 days) left as-is — this is a reasonable fixed value.

---

### 8. prod Renamed to demo

All references to `"prod"` as an environment name updated to `"demo"`:

- `terraform/variables.tf`: validation condition `contains(["dev", "prod"], ...)` → `contains(["dev", "demo"], ...)`
- `terraform/modules/ecs/main.tf`: ASPNETCORE_ENVIRONMENT detection `var.environment == "prod"` → `var.environment == "demo"`
- All module `variables.tf` description strings updated
- `deploy-prod.yml` workflow deleted; `deploy-demo.yml` created
- `post-merge-build.yml` environment options updated (dev, demo)

---

## CI/CD Workflow Updates (PTS-21)

Files updated under `.github/workflows/`:

| File | Change |
|---|---|
| `deploy-prod.yml` | Deleted |
| `deploy-demo.yml` | Created — targets demo environment, references updated ECR repo names |
| `deploy-dev.yml` | Updated ECR image URI (removed env suffix from repo name) |
| `post-merge-build.yml` | Updated environment options (dev/demo), updated ECR URL construction |
| `initial-setup.yml` | Updated PROJECT_NAME comment to reflect `pts` |

---

## Acceptance Criteria Verification

- `terraform validate` — run after confirming `terraform init` with backend config
- ECR repo names: `pts-trading-api`, `pts-lifecycle-lambda` (no env suffix)
- `terraform/modules/iam/` deleted
- `terraform/modules/ecs/iam.tf` and `terraform/modules/lambda/iam.tf` created
- `terraform/iam.tf` created with OIDC resources
- Log groups: `/${environment}/trading-api`, `/${environment}/lifecycle-engine`
- `terraform/environments/dev.tfvars` and `terraform/environments/demo.tfvars` present
- `terraform/modules/networking/main.tf` absent — replaced by 5 focused files
- No `"prod"` environment string references in any `.tf` file
