# GitHub Actions Reference — Pets Trading System

## Table of Contents
1. [OIDC Auth Shared Setup](#1-oidc-auth-shared-setup)
2. [Backend Pipeline (Trading API)](#2-backend-pipeline-trading-api)
3. [Lifecycle Lambda Pipeline](#3-lifecycle-lambda-pipeline)
4. [Frontend Pipeline (React SPA)](#4-frontend-pipeline-react-spa)
5. [Terraform Plan/Apply Pipeline](#5-terraform-plannapply-pipeline)
6. [Reusable Workflows](#6-reusable-workflows)
7. [Branch Strategy & Environment Gates](#7-branch-strategy--environment-gates)

---

## 1. OIDC Auth Shared Setup

Never store `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` as GitHub secrets. Use OIDC to assume the IAM role created in Terraform.

```yaml
# Reusable permissions block — add to every job that talks to AWS
permissions:
  id-token: write    # required for OIDC token request
  contents: read

# Reusable AWS auth step
- name: Configure AWS credentials (OIDC)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
    role-session-name: GHActions-${{ github.run_id }}
```

**Required GitHub repository variables** (not secrets):
- `AWS_DEPLOY_ROLE_ARN` — ARN of the OIDC IAM role
- `AWS_REGION` — e.g., `us-east-1`
- `ECR_REGISTRY` — ECR registry URL
- `CLOUDFRONT_DISTRIBUTION_ID` — for frontend invalidation

---

## 2. Backend Pipeline (Trading API)

```yaml
# .github/workflows/backend.yml
name: Backend — Trading API

on:
  push:
    branches: [main]
    paths: ["src/**", "tests/**", ".github/workflows/backend.yml"]
  pull_request:
    branches: [main]
    paths: ["src/**", "tests/**"]

env:
  ECR_REPO: petstrading/trading-api
  IMAGE_NAME: ${{ vars.ECR_REGISTRY }}/petstrading/trading-api

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET 10
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "10.0.x"

      - name: Restore
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore --configuration Release

      - name: Test
        run: >
          dotnet test --no-build --configuration Release
          --collect:"XPlat Code Coverage"
          --results-directory ./coverage/
        env:
          ASPNETCORE_ENVIRONMENT: Test

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        if: github.event_name == 'push'
        with:
          directory: ./coverage/

  build-push:
    name: Build & Push ECR
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    permissions:
      id-token: write
      contents: read
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Login to ECR
        id: ecr-login
        uses: aws-actions/amazon-ecr-login@v2

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=,format=short
            type=semver,pattern={{version}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./src/PetsTrading.Api/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            BUILD_VERSION=${{ steps.meta.outputs.version }}

      - name: Scan image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          exit-code: 1   # fail on critical vulnerabilities

  deploy-dev:
    name: Deploy → Dev
    runs-on: ubuntu-latest
    needs: build-push
    environment: dev
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Update ECS service
        run: |
          IMAGE="${{ vars.ECR_REGISTRY }}/${{ env.ECR_REPO }}:${{ needs.build-push.outputs.image-tag }}"
          # Get current task definition, replace image, register new revision, update service
          TASK_DEF=$(aws ecs describe-task-definition \
            --task-definition petstrading-trading-api-dev \
            --query 'taskDefinition')
          NEW_TASK_DEF=$(echo "$TASK_DEF" | jq \
            --arg IMAGE "$IMAGE" \
            '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.placementConstraints,.registeredAt,.registeredBy,.compatibilities)')
          NEW_ARN=$(aws ecs register-task-definition \
            --cli-input-json "$NEW_TASK_DEF" \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)
          aws ecs update-service \
            --cluster petstrading-dev \
            --service trading-api \
            --task-definition "$NEW_ARN" \
            --force-new-deployment

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster petstrading-dev \
            --services trading-api

  deploy-prod:
    name: Deploy → Prod
    runs-on: ubuntu-latest
    needs: [build-push, deploy-dev]
    environment: prod   # requires manual approval in GitHub environment settings
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Update ECS service (prod)
        run: |
          IMAGE="${{ vars.ECR_REGISTRY }}/${{ env.ECR_REPO }}:${{ needs.build-push.outputs.image-tag }}"
          TASK_DEF=$(aws ecs describe-task-definition \
            --task-definition petstrading-trading-api-prod \
            --query 'taskDefinition')
          NEW_TASK_DEF=$(echo "$TASK_DEF" | jq \
            --arg IMAGE "$IMAGE" \
            '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.placementConstraints,.registeredAt,.registeredBy,.compatibilities)')
          NEW_ARN=$(aws ecs register-task-definition \
            --cli-input-json "$NEW_TASK_DEF" \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)
          aws ecs update-service \
            --cluster petstrading-prod \
            --service trading-api \
            --task-definition "$NEW_ARN"

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster petstrading-prod \
            --services trading-api
```

---

## 3. Lifecycle Lambda Pipeline

```yaml
# .github/workflows/lambda.yml
name: Lifecycle Lambda

on:
  push:
    branches: [main]
    paths: ["lambda/**", ".github/workflows/lambda.yml"]

env:
  ECR_REPO: petstrading/lifecycle-lambda

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: "10.0.x" }
      - run: dotnet test lambda/ --configuration Release

  build-push-deploy:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - uses: aws-actions/amazon-ecr-login@v2

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ vars.ECR_REGISTRY }}/${{ env.ECR_REPO }}
          tags: type=sha,prefix=,format=short

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./lambda
          file: ./lambda/PetsTrading.LifecycleLambda/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Update Lambda function code
        run: |
          aws lambda update-function-code \
            --function-name petstrading-lifecycle-prod \
            --image-uri "${{ vars.ECR_REGISTRY }}/${{ env.ECR_REPO }}:${{ steps.meta.outputs.version }}" \
            --publish
          aws lambda wait function-updated \
            --function-name petstrading-lifecycle-prod
```

---

## 4. Frontend Pipeline (React SPA)

```yaml
# .github/workflows/frontend.yml
name: Frontend — React SPA

on:
  push:
    branches: [main]
    paths: ["frontend/**", ".github/workflows/frontend.yml"]
  pull_request:
    paths: ["frontend/**"]

jobs:
  test:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: frontend } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20"; cache: npm; cache-dependency-path: frontend/package-lock.json }
      - run: npm ci
      - run: npm run lint
      - run: npm run test:ci   # vitest run --reporter=junit

  build-deploy:
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: frontend } }
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20"; cache: npm; cache-dependency-path: frontend/package-lock.json }
      - run: npm ci

      - name: Build
        run: npm run build
        env:
          VITE_API_URL: ${{ vars.API_URL }}
          VITE_WEBSOCKET_URL: ${{ vars.WEBSOCKET_URL }}
          VITE_COGNITO_USER_POOL_ID: ${{ vars.COGNITO_USER_POOL_ID }}
          VITE_COGNITO_CLIENT_ID: ${{ vars.COGNITO_CLIENT_ID }}

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Sync to S3
        run: |
          # Hashed assets: cache 1 year
          aws s3 sync dist/ s3://${{ vars.FRONTEND_BUCKET }} \
            --delete \
            --cache-control "public, max-age=31536000, immutable" \
            --exclude "index.html"
          # index.html: no cache (always latest)
          aws s3 cp dist/index.html s3://${{ vars.FRONTEND_BUCKET }}/index.html \
            --cache-control "no-cache, no-store, must-revalidate"

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ vars.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
```

---

## 5. Terraform Plan/Apply Pipeline

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  pull_request:
    paths: ["terraform/**"]
  push:
    branches: [main]
    paths: ["terraform/**"]

env:
  TF_DIR: terraform/environments/prod

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: "~> 1.9" }

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Terraform Init
        run: terraform init
        working-directory: ${{ env.TF_DIR }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: terraform/

      - name: Terraform Validate
        run: terraform validate
        working-directory: ${{ env.TF_DIR }}

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan 2>&1 | tee plan.txt
        working-directory: ${{ env.TF_DIR }}

      - name: Comment plan on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('${{ env.TF_DIR }}/plan.txt', 'utf8');
            const output = `#### Terraform Plan 📋\n\`\`\`\n${plan.substring(0, 60000)}\n\`\`\``;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

  apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    needs: plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: prod   # manual approval gate
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: "~> 1.9" }
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - run: terraform init
        working-directory: ${{ env.TF_DIR }}
      - run: terraform apply -auto-approve
        working-directory: ${{ env.TF_DIR }}
```

---

## 6. Reusable Workflows

Extract common steps into reusable workflows to avoid duplication:

```yaml
# .github/workflows/_aws-auth.yml
on:
  workflow_call:
    inputs:
      aws-region:
        required: true
        type: string
    secrets:
      role-arn:
        required: true

jobs:
  auth:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.role-arn }}
          aws-region: ${{ inputs.aws-region }}
```

---

## 7. Branch Strategy & Environment Gates

```
main ────────────────────────────────────────► prod (requires PR approval + green CI)
  │
  └── feature/* ──► PR ──► CI runs tests + terraform plan ──► merge to main
```

**GitHub Environment settings:**
- `dev` — auto-deploy, no approval required
- `prod` — required reviewer approval before deployment

**Required status checks on `main`:**
- `test` (all test jobs)
- `terraform plan` (if terraform/** changed)

**Rollback procedure:**
```bash
# ECS rolling rollback to previous task definition
PREV_ARN=$(aws ecs describe-task-definition \
  --task-definition petstrading-trading-api-prod \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text | sed 's/:[0-9]*$//'):<PREV_REVISION>

aws ecs update-service \
  --cluster petstrading-prod \
  --service trading-api \
  --task-definition $PREV_ARN

# Lambda rollback to previous version
aws lambda update-alias \
  --function-name petstrading-lifecycle-prod \
  --name live \
  --function-version <PREV_VERSION>
```
