# ADR-010: GitHub Actions for CI/CD Pipeline

## Status
Accepted

## Context
The system needs a CI/CD pipeline that builds .NET services, runs tests, builds Docker images, pushes to ECR, runs Terraform, and deploys to ECS and S3. The pipeline should be triggered by pull requests and pushes to the main branch.

## Decision
Use **GitHub Actions** for the complete CI/CD pipeline with separate workflows for CI (pull request validation) and CD (deployment on merge to main).

## Consequences
**Easier:**
- Integrated with the GitHub repository (no external CI/CD system to configure)
- Free tier provides 2,000 minutes/month for private repos (sufficient for hackathon)
- YAML workflow files are version-controlled alongside code
- Rich marketplace of actions for .NET, Docker, Terraform, AWS
- OIDC federation for AWS authentication (no long-lived access keys)
- Parallel job execution for faster pipelines
- Environment protection rules for production deployments

**Harder:**
- GitHub-hosted runners may have queue delays during peak times
- Self-hosted runners needed for VPC-internal operations (not required for this project)
- Debugging workflow failures requires iterating on commits
- Secret management in GitHub Actions requires manual setup

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **GitLab CI/CD** | Repository is on GitHub; adding GitLab adds complexity |
| **Azure DevOps** | Additional service; not integrated with GitHub repository |
| **AWS CodePipeline + CodeBuild** | More complex setup; less flexible than GitHub Actions; vendor lock-in |
| **Jenkins** | Self-hosted; maintenance overhead; no free managed option |
