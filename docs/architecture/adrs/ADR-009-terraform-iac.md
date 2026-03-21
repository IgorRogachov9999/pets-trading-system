# ADR-009: Terraform for Infrastructure as Code

## Status
Accepted

## Context
The hackathon judging matrix awards points for infrastructure definition and environment configuration. Infrastructure must be reproducible, version-controlled, and able to provision the full AWS stack (VPC, ECS, RDS, API Gateway, Lambda, Cognito, S3, CloudFront, IAM, etc.).

## Decision
Use **Terraform** (HashiCorp) with **AWS provider** for all infrastructure provisioning. State stored in **S3** with **DynamoDB** locking.

## Consequences
**Easier:**
- Declarative syntax makes infrastructure reviewable and diffable
- Terraform workspaces support multiple environments (dev, prod)
- AWS provider covers all required services comprehensively
- State locking with DynamoDB prevents concurrent modifications
- `terraform plan` provides preview of changes before apply
- Team familiarity with HCL syntax
- Large module ecosystem for common patterns (VPC, ECS, RDS)

**Harder:**
- State file management requires pre-existing S3 bucket and DynamoDB table
- Learning curve for complex resources (API Gateway WebSocket, VPC endpoints)
- No built-in drift detection (requires `terraform plan` runs)
- Provider version pinning needed for reproducibility

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **AWS CDK** | TypeScript/Python wrapper; adds abstraction layer; team more familiar with Terraform |
| **AWS SAM** | Focused on serverless; limited support for ECS, VPC, RDS |
| **CloudFormation** | Verbose YAML/JSON; slower feedback loop; no multi-cloud option |
| **Pulumi** | Less team familiarity; smaller community; similar capabilities to Terraform |
