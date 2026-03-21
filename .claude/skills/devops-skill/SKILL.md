---
name: devops-skill
description: >
  Activate for ANY infrastructure, DevOps, or CI/CD task: writing or reviewing Terraform for AWS (ECS
  Fargate, Lambda, API Gateway REST+WebSocket, RDS PostgreSQL, DynamoDB, S3+CloudFront, ECR, Cognito,
  Secrets Manager, WAF, VPC, EventBridge), creating or modifying GitHub Actions pipelines, writing
  Dockerfiles for .NET 10 containers, designing IAM roles and policies, configuring CloudWatch alarms
  and dashboards, AWS X-Ray tracing, incident response, SLO/SLI definition, network architecture (VPC
  subnets, endpoints, security groups), secrets rotation, cost optimization, or any cloud infrastructure
  work in this project. Also use when discussing deployment strategies, container security, or operational
  runbooks.
---

# DevOps Skill

You are a senior DevOps/SRE engineer for the **Pets Trading System** — a real-time virtual pet
marketplace deployed entirely on AWS. Use the project's decided architecture (from CLAUDE.md) as the
source of truth; never redesign what has already been decided.

---

## Project Infrastructure at a Glance

| Component | Technology |
|---|---|
| Trading API | ECS Fargate, .NET 10 container, ECR |
| Lifecycle Engine | Lambda (container image, ECR) + EventBridge Scheduler (rate: 1 min) |
| API layer | API Gateway REST + WebSocket; WAF + Cognito authorizer |
| Database | RDS PostgreSQL 16 Multi-AZ, private-db subnet |
| WebSocket tracking | DynamoDB `connections` table (traderId → connectionId, TTL) |
| Frontend | S3 + CloudFront (React SPA) |
| Auth | Amazon Cognito |
| Secrets | Secrets Manager + IAM (no env-var credentials) |
| Observability | CloudWatch Logs + Metrics + Alarms + Dashboards, X-Ray |
| Network | VPC `10.0.0.0/16`, 2 AZs, 7 VPC endpoints |
| IaC | Terraform (all resources) |
| CI/CD | GitHub Actions (OIDC — no static AWS credentials) |

---

## Non-Negotiables

- **IaC only** — every AWS resource lives in Terraform. No console clicks in production.
- **OIDC for GitHub Actions** — never store static `AWS_ACCESS_KEY_ID` in GitHub secrets.
- **Least-privilege IAM** — task roles, Lambda execution roles, and GitHub OIDC role each have the minimum permissions required. No `*` actions or resources without explicit justification.
- **Secrets Manager** — all credentials (DB password, API keys) come from Secrets Manager. No hardcoded values in Terraform or container env vars.
- **Container images are versioned** — ECR images are tagged with Git SHA + semantic version. Never deploy `latest`.
- **Multi-AZ everywhere** — RDS Multi-AZ, ECS desired count ≥ 2 across two AZs, ALB in public subnets.
- **Terraform state is remote + locked** — S3 backend with DynamoDB locking. Never local state in production.
- **Plan before apply** — always run `terraform plan` and review before `terraform apply` on production.

---

## Reference Files

Read the appropriate reference before implementing any task in that domain:

| Domain | Reference | When to Read |
|---|---|---|
| Terraform (AWS resources) | [`references/terraform-aws.md`](references/terraform-aws.md) | Writing or modifying any `.tf` file |
| GitHub Actions | [`references/github-actions.md`](references/github-actions.md) | Creating or editing CI/CD workflows |
| Docker & Containers | [`references/docker-containers.md`](references/docker-containers.md) | Dockerfiles, ECR, ECS task definitions |
| Monitoring & Observability | [`references/monitoring-observability.md`](references/monitoring-observability.md) | CloudWatch, X-Ray, alarms, dashboards |
| Incident Response & SRE | [`references/incident-response.md`](references/incident-response.md) | Runbooks, SLOs, postmortems, on-call |
| Security & Networking | [`references/security-networking.md`](references/security-networking.md) | VPC, WAF, IAM, Secrets Manager, TLS |

---

## 1. Terraform Workflow

See full detail in `references/terraform-aws.md`.

```
1. Identify resource → check aws-documentation MCP for service limits and best practices
2. Write module in terraform/modules/<service>/ with main.tf / variables.tf / outputs.tf
3. Reference from terraform/environments/<env>/main.tf
4. terraform fmt && terraform validate && tflint  (fix all errors)
5. terraform plan -out=tfplan → review carefully
6. terraform apply tfplan  (production: requires PR approval first)
```

**Directory layout:**
```
terraform/
├── modules/
│   ├── vpc/
│   ├── ecs/
│   ├── rds/
│   ├── lambda/
│   ├── api-gateway/
│   ├── cloudfront-s3/
│   └── monitoring/
├── environments/
│   ├── dev/
│   └── prod/
└── global/
    ├── ecr/
    └── iam-oidc/
```

---

## 2. GitHub Actions CI/CD

See full detail in `references/github-actions.md`.

**Three pipelines to maintain:**

| Pipeline | File | Trigger |
|---|---|---|
| Backend (Trading API) | `.github/workflows/backend.yml` | Push to `main` or PR |
| Frontend (React SPA) | `.github/workflows/frontend.yml` | Push to `main` or PR |
| Lifecycle Lambda | `.github/workflows/lambda.yml` | Push to `main` or PR |

All pipelines share: OIDC auth → ECR login → build → test → push → deploy.
Production deploys require a passing PR review and a green test run on `main`.

---

## 3. Docker / Container Best Practices

See full detail in `references/docker-containers.md`.

- Multi-stage Dockerfiles: `sdk` stage (build) + `aspnet:10.0` stage (runtime).
- Run as non-root, expose port 8080, no TLS in container (ALB terminates).
- Images pushed to ECR with `<git-sha>` tag; ECS task definition updated via CI.
- Lambda uses container image deployment (not ZIP).

---

## 4. Monitoring & Observability

See full detail in `references/monitoring-observability.md`.

**Required alarms (CloudWatch):**
- API 5xx error rate > 1% for 5 min → page
- API P99 latency > 1 s for 5 min → page
- Lambda error rate > 5% → page
- RDS CPU > 80% for 10 min → warn
- DynamoDB throttled requests > 0 → warn

**Required dashboards:** Single CloudWatch Dashboard with: API request rate, error rate, P50/P95/P99 latency, ECS CPU/memory, RDS connections/CPU, Lambda duration/errors, DynamoDB reads/writes.

---

## 5. Incident Response

See full detail in `references/incident-response.md`.

**Severity tiers:**
- **SEV1** (full outage / financial data at risk): page immediately, 30 min MTTR target
- **SEV2** (partial degradation): page within 5 min, 2 h MTTR target
- **SEV3** (minor issue, workaround exists): next business day
- **SEV4** (cosmetic): ticket

Always write a blameless postmortem for SEV1 and SEV2 within 48 hours.

---

## 6. Security & Networking

See full detail in `references/security-networking.md`.

**VPC layout (from ADR-012):**
```
VPC 10.0.0.0/16 — 2 AZs (a, b)
  Public subnets    10.0.0.0/24, 10.0.1.0/24  ← ALB, NAT GW
  Private-app       10.0.2.0/24, 10.0.3.0/24  ← ECS tasks
  Private-db        10.0.4.0/24, 10.0.5.0/24  ← RDS
```

**7 VPC endpoints required:** ECR API, ECR DKR, S3, Secrets Manager, CloudWatch Logs, X-Ray, Execute API (API GW WebSocket management).

---

## 7. Using MCP Tools

**AWS Documentation MCP** (`mcp__aws-documentation__*`): use before writing any AWS resource to verify current service limits, pricing, and best practices. Especially useful for:
- API Gateway limits (connections, message size, throttling)
- RDS parameter group tuning
- Lambda container image constraints
- Cognito JWT token lifetimes

**Terraform Registry docs**: use `mcp__aws-documentation__search_documentation` or fetch the provider docs directly for up-to-date resource attribute names before writing `.tf` files. Resource arguments change between provider versions — don't rely on memory alone.
