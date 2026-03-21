# Docker & Containers Reference — Pets Trading System

## Table of Contents
1. [Trading API Dockerfile (.NET 10)](#1-trading-api-dockerfile-net-10)
2. [Lifecycle Lambda Dockerfile (.NET 10)](#2-lifecycle-lambda-dockerfile-net-10)
3. [Security Best Practices](#3-security-best-practices)
4. [ECR Image Tagging Strategy](#4-ecr-image-tagging-strategy)
5. [ECS Task Definition Patterns](#5-ecs-task-definition-patterns)
6. [Local Development with Docker Compose](#6-local-development-with-docker-compose)

---

## 1. Trading API Dockerfile (.NET 10)

```dockerfile
# src/PetsTrading.Api/Dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

# Restore as distinct layer — cache until .csproj changes
COPY ["src/PetsTrading.Api/PetsTrading.Api.csproj", "src/PetsTrading.Api/"]
COPY ["src/PetsTrading.Application/PetsTrading.Application.csproj", "src/PetsTrading.Application/"]
COPY ["src/PetsTrading.Domain/PetsTrading.Domain.csproj", "src/PetsTrading.Domain/"]
COPY ["src/PetsTrading.Infrastructure/PetsTrading.Infrastructure.csproj", "src/PetsTrading.Infrastructure/"]
RUN dotnet restore "src/PetsTrading.Api/PetsTrading.Api.csproj"

# Copy everything and build
COPY . .
RUN dotnet publish "src/PetsTrading.Api/PetsTrading.Api.csproj" \
    --configuration Release \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Run as non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

# ALB terminates TLS; container speaks plain HTTP on 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "PetsTrading.Api.dll"]
```

---

## 2. Lifecycle Lambda Dockerfile (.NET 10)

```dockerfile
# lambda/PetsTrading.LifecycleLambda/Dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

COPY ["PetsTrading.LifecycleLambda.csproj", "."]
RUN dotnet restore

COPY . .
RUN dotnet publish \
    --configuration Release \
    --no-restore \
    --output /app/publish

# AWS Lambda .NET base image
FROM public.ecr.aws/lambda/dotnet:10 AS runtime
WORKDIR /var/task

COPY --from=build /app/publish .
CMD ["PetsTrading.LifecycleLambda::PetsTrading.LifecycleLambda.Function::FunctionHandler"]
```

---

## 3. Security Best Practices

| Practice | How |
|---|---|
| Non-root user | `adduser appuser` + `USER appuser` in runtime stage |
| Minimal base | Use `aspnet:10.0` not `sdk:10.0` in runtime (sdk is 600MB+) |
| No secrets in image | Secrets come from Secrets Manager at runtime via ECS secrets / Lambda env |
| Pinned versions | `mcr.microsoft.com/dotnet/aspnet:10.0` — never `latest` |
| Image scanning | ECR `scan_on_push = true`; Trivy in CI with `exit-code = 1` on CRITICAL/HIGH |
| Health check | `/health` endpoint; defined in ECS task definition |
| Read-only filesystem | Consider `ReadonlyRootFilesystem: true` in ECS task definition where possible |
| No debug endpoints | `ASPNETCORE_ENVIRONMENT=Production` disables developer exception page |

**.dockerignore** (prevents build context bloat):
```
**/.git
**/bin
**/obj
**/.vs
**/node_modules
**/*.user
**/Dockerfile*
.gitignore
README.md
terraform/
.github/
frontend/
tests/
```

---

## 4. ECR Image Tagging Strategy

```
<git-sha-short>    e.g., a1b2c3d    → primary tag from CI
v<semver>          e.g., v1.2.3     → release tags via git tag
```

Rules:
- `IMMUTABLE` tag mutability in ECR — you can never overwrite an existing tag.
- CI always pushes `<sha>` tag; ECS/Lambda deployment references the `<sha>`.
- Never reference `latest` in ECS task definitions or Lambda function code.
- Semantic version tags are optional but recommended for release tracking.

**Update ECS to a new image:**
```bash
# Get current task definition
TASK=$(aws ecs describe-task-definition --task-definition petstrading-trading-api-prod)

# Replace image tag and register new revision
NEW_TASK=$(echo "$TASK" | jq \
  --arg NEW_IMAGE "123456789.dkr.ecr.us-east-1.amazonaws.com/petstrading/trading-api:a1b2c3d" \
  '.taskDefinition.containerDefinitions[0].image = $NEW_IMAGE |
   .taskDefinition | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.placementConstraints,.registeredAt,.registeredBy,.compatibilities)')

NEW_ARN=$(aws ecs register-task-definition \
  --cli-input-json "$NEW_TASK" \
  --query 'taskDefinition.taskDefinitionArn' --output text)

aws ecs update-service \
  --cluster petstrading-prod \
  --service trading-api \
  --task-definition "$NEW_ARN"
```

---

## 5. ECS Task Definition Patterns

Key settings for the Trading API task definition:

```json
{
  "family": "petstrading-trading-api-prod",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [{
    "name": "trading-api",
    "image": "<ecr-url>:<git-sha>",
    "essential": true,
    "portMappings": [{ "containerPort": 8080, "protocol": "tcp" }],
    "readonlyRootFilesystem": false,
    "environment": [
      { "name": "ASPNETCORE_ENVIRONMENT", "value": "Production" }
    ],
    "secrets": [
      { "name": "ConnectionStrings__Postgres",
        "valueFrom": "arn:aws:secretsmanager:...:db:connectionString::" }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/petstrading-trading-api",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
      "interval": 30,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 60
    },
    "ulimits": [{ "name": "nofile", "softLimit": 65536, "hardLimit": 65536 }]
  }]
}
```

---

## 6. Local Development with Docker Compose

```yaml
# docker-compose.yml (development only)
version: "3.9"
services:
  api:
    build:
      context: .
      dockerfile: src/PetsTrading.Api/Dockerfile
      target: build    # use build stage for hot-reload
    ports:
      - "8080:8080"
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      ConnectionStrings__Postgres: "Host=postgres;Database=petstrading;Username=petstrading;Password=devpassword"
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./src:/source/src    # mount source for file watching

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: petstrading
      POSTGRES_USER: petstrading
      POSTGRES_PASSWORD: devpassword
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U petstrading"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```
