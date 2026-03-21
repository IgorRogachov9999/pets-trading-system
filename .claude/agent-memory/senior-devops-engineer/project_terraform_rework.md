---
name: Terraform Rework — Key Infrastructure Patterns
description: Patterns, conventions, and structural decisions established by the PTS-20 Terraform rework
type: project
---

ECR repositories are shared across environments — no environment suffix in repo names (`pts-trading-api`, `pts-lifecycle-lambda`). The `environment` variable is still accepted by the ECR module but unused in resource names/tags.

**Why:** ECR is account-scoped; tagging per-environment makes no sense when all envs pull from the same registry.
**How to apply:** When adding new container repos, follow the pattern `${var.project_name}-<service>` without env suffix. IAM policies scoping ECR access in `terraform/iam.tf` reference these names without env.

---

IAM roles are owned by their consuming module — not a central IAM module.

- ECS task execution role + ECS task role: `terraform/modules/ecs/iam.tf`
- Lambda execution role: `terraform/modules/lambda/iam.tf`
- GitHub Actions OIDC provider + role: `terraform/iam.tf` (root, cross-cutting)

**Why:** Eliminates circular dependency risk between IAM and service modules; keeps permissions co-located with the service that needs them.
**How to apply:** When adding a new service module (e.g., a new Lambda), create an `iam.tf` in that module. Never add IAM roles back to a top-level IAM module.

---

CloudWatch log group naming pattern: `/${var.environment}/<service-name>`

- Trading API: `/${var.environment}/trading-api`
- Lifecycle Lambda: `/${var.environment}/lifecycle-engine`

IAM policies reference these exact ARN patterns.

---

Environments: `dev` (1 AZ, db.t3.micro, ECS 256/512) and `demo` (2 AZ, db.t3.small, ECS 512/1024). No `prod`. tfvars in `terraform/environments/`.

---

Networking module is split into 5 files: `vpc.tf`, `subnets.tf`, `routing.tf`, `security_groups.tf`, `endpoints.tf`. There is no `main.tf` in the networking module.

---

Provider `default_tags` covers `Project`, `Environment`, `Terraform = "true"`, `ManagedBy = "terraform"`. Per-resource tags should only add `Name` (and optional tier/purpose tags); do not repeat Project/Environment.
