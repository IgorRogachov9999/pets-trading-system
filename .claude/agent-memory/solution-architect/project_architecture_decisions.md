---
name: Architecture Technology Stack
description: Confirmed technology choices for the Pets Trading System -- AWS, .NET 10 LTS, React, PostgreSQL, ECS Fargate, Terraform, GitHub Actions
type: project
---

Architecture technology stack confirmed on 2026-03-20 (updated 2026-03-20 -- .NET 8 upgraded to .NET 10 LTS):
- Cloud: AWS (us-east-1)
- Backend: .NET 10 LTS (C#) microservices on ECS Fargate (container images via ECR)
- Frontend: React 18 + TypeScript on S3 + CloudFront
- Database: RDS PostgreSQL 16 (Multi-AZ) with Dapper ORM, IAM auth
- API: AWS API Gateway (REST + WebSocket)
- Auth: Amazon Cognito
- Event-driven: AWS Lambda (.NET 10, container image deployment -- no managed runtime constraint) + EventBridge
- IaC: Terraform (S3 backend + DynamoDB locking)
- CI/CD: GitHub Actions
- Observability: CloudWatch + X-Ray
- Container Registry: ECR
- Secrets: AWS Secrets Manager

**Why:** .NET 10 LTS chosen over .NET 8 for longer support (Nov 2028 vs Nov 2026), improved container performance (chiseled images), faster JIT/GC, and better ASP.NET Core minimal API support. Container-first deployment (ECS Fargate + Lambda container images) removes any AWS managed runtime constraint.

**How to apply:** Use .NET 10 LTS as the baseline for all backend implementation. All ADRs (ADR-001 through ADR-014) are updated. Dockerfiles should use `mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled` base images.
