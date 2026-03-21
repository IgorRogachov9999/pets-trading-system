# Task 4: CI/CD — GitHub Actions PR Checks and Deploy Pipelines

**Jira**: [PTS-21](https://igorrogachov9999.atlassian.net/browse/PTS-21)
**Story**: [TS-001](./story.md)
**Label**: `devops`
**Depends on**: PTS-18 (backend), PTS-19 (frontend), PTS-20 (Terraform)

---

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `backend-pr-check.yml` | PR → main (`src/trading-api/**`) | dotnet restore → build → test → upload TRX |
| `frontend-pr-check.yml` | PR → main (`src/ui/**`) | npm ci → build → test |
| `initial-setup.yml` | push → main (ENABLED) | Full bootstrap: TF apply → build images → build UI → deploy all |
| `post-merge-build.yml` | workflow_dispatch (disabled) | Build & push images + frontend artifact; no deploy |
| `deploy-dev.yml` | workflow_dispatch (disabled) | TF apply + deploy to dev; enable after bootstrap |
| `deploy-prod.yml` | workflow_dispatch (disabled) | TF apply + deploy to prod; requires `prod` environment approval |
| `backend-deploy.yml` | workflow_dispatch (SUPERSEDED) | Replaced by initial-setup.yml / deploy-dev.yml |
| `frontend-deploy.yml` | workflow_dispatch (SUPERSEDED) | Replaced by initial-setup.yml / deploy-dev.yml |

---

## Pipeline Lifecycle

```
Phase 1 — Bootstrap (current)
  push to main → initial-setup.yml
    └── terraform apply (dev)
    └── build & push trading-api + lifecycle-lambda images to ECR
    └── build React UI → upload to builds S3
    └── deploy ECS + Lambda + frontend S3 + CloudFront invalidation

Phase 2 — Steady state (enable after infra is stable)
  1. Disable initial-setup.yml
  2. Enable post-merge-build.yml (builds only)
  3. Enable deploy-dev.yml (deploy dev on demand)
  4. Enable deploy-prod.yml (deploy prod with approval gate)
```

---

## Required GitHub Secrets (Updated)

| Secret | Required By | Value Source |
|--------|-------------|-------------|
| `AWS_ROLE_ARN` | All deploy pipelines | IAM → Terraform output `github_actions_role_arn` |
| `AWS_REGION` | All deploy pipelines | e.g., `us-east-1` |
| `PROJECT_NAME` | All deploy pipelines | `pets-trading-system` |
| `TF_STATE_BUCKET` | Terraform pipelines | Pre-created S3 bucket (see bootstrap instructions below) |
| `TF_STATE_LOCK_TABLE` | Terraform pipelines | Pre-created DynamoDB table (see bootstrap instructions below) |
| `PROD_CLOUDFRONT_DISTRIBUTION_ID` | `deploy-prod.yml` | Set after first prod `terraform apply` |

---

## Bootstrap Prerequisites (Before Running initial-setup.yml)

Manually create these AWS resources once before the first pipeline run.
The S3 bucket and DynamoDB table store Terraform remote state and must exist before
Terraform can initialise.

```bash
# 1. S3 state bucket (versioning + encryption required)
aws s3api create-bucket \
  --bucket pets-trading-system-tf-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket pets-trading-system-tf-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket pets-trading-system-tf-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Block public access (belt-and-braces)
aws s3api put-public-access-block \
  --bucket pets-trading-system-tf-state \
  --public-access-block-configuration \
  'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

# 2. DynamoDB lock table
aws dynamodb create-table \
  --table-name pets-trading-system-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

After creating these resources, set the GitHub Secrets:

```
TF_STATE_BUCKET     = pets-trading-system-tf-state
TF_STATE_LOCK_TABLE = pets-trading-system-tf-locks
```

---

## Local Development: Terraform Init

Copy the example file and fill in your values:

```bash
cp terraform/backend-dev.hcl.example terraform/backend-dev.hcl
# edit terraform/backend-dev.hcl with your bucket/table names
terraform -chdir=terraform init -backend-config=backend-dev.hcl
```

`terraform/backend-dev.hcl` is gitignored. Never commit it.

---

## IAM Trust Policy (for OIDC role)

The `AWS_ROLE_ARN` role must have a trust policy allowing GitHub Actions OIDC:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<ACCOUNT>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:ihorrohachov/pets-trading-system:*"
    }
  }
}
```

This role is provisioned by the Terraform `iam-oidc` module. The ARN is exported as
`github_actions_role_arn` and must be set as the `AWS_ROLE_ARN` secret.

---

## Acceptance Criteria

- All 7 workflow files are valid YAML
- `initial-setup.yml` triggers on push to main and runs the full bootstrap sequence
- `post-merge-build.yml`, `deploy-dev.yml`, `deploy-prod.yml` trigger only on `workflow_dispatch`
- `backend-deploy.yml` and `frontend-deploy.yml` are disabled (workflow_dispatch + exit 1)
- No long-lived AWS credentials stored as GitHub secrets — OIDC only
- Bootstrap prerequisites documented and reproducible
