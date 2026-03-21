# TS-001: Project Base Setup

**Type**: Technical Story (not linked to any business epic)
**Jira**: [PTS-17](https://igorrogachov9999.atlassian.net/browse/PTS-17)
**Priority**: High
**Labels**: `technical`, `setup`

## Goal

Establish the foundational project scaffold that all future feature work depends on:

1. .NET 10 Trading API skeleton — compiles, has a health endpoint, passes unit tests
2. React SPA skeleton — compiles, calls the backend health endpoint, passes unit tests
3. Terraform infrastructure — ECR repository, S3 bucket + CloudFront for early builds
4. GitHub Actions CI/CD — PR check pipelines (build + test) and deploy pipelines

## Acceptance Criteria

- [ ] `src/trading-api/` contains a runnable .NET 10 ASP.NET Core project with `GET /api/health` returning `{"message": "Pets Trading System API is running"}`
- [ ] `src/trading-api/` contains a unit test project with at least one passing test
- [ ] `src/ui/` contains a runnable React+TypeScript+Vite project that calls `/api/health` and displays the message
- [ ] `src/ui/` contains Vitest unit tests with at least one passing test
- [ ] `terraform/` contains infrastructure code for ECR, S3+CloudFront
- [ ] `.github/workflows/` contains PR check workflows (build + test) for backend and frontend
- [ ] `.github/workflows/` contains deploy workflows for backend (ECR) and frontend (S3)

## Tasks

| Task | Jira | Domain | Depends On |
|------|------|--------|------------|
| [Task 1: Backend Setup](./task-1-backend-setup.md) | PTS-18 | Backend | — |
| [Task 2: Frontend Setup](./task-2-frontend-setup.md) | PTS-19 | Frontend | — |
| [Task 3: Terraform Infrastructure](./task-3-terraform.md) | PTS-20 | DevOps | — |
| [Task 4: CI/CD Pipelines](./task-4-cicd.md) | PTS-21 | DevOps | PTS-18, PTS-19, PTS-20 |
