# arc42: 02 -- Constraints

## 2.1 Technical Constraints

| ID | Constraint | Rationale |
|----|-----------|-----------|
| TC-001 | AWS as sole cloud provider | Team decision; all infrastructure on AWS |
| TC-002 | .NET 10 LTS (C#) for backend microservices | Team expertise; strong typing, mature ecosystem; LTS support through Nov 2028 |
| TC-003 | React for frontend SPA | Team expertise; component-based UI, rich ecosystem |
| TC-004 | PostgreSQL (RDS) as primary database | Relational model fits trading domain; ACID guarantees |
| TC-005 | Dapper as ORM | Lightweight; direct SQL control; performance |
| TC-006 | ECS Fargate for container orchestration | Serverless containers; no cluster management |
| TC-007 | Terraform for IaC | Multi-provider support; declarative; team familiarity |
| TC-008 | GitHub Actions for CI/CD | Integrated with repository; free tier for hackathon |
| TC-009 | Pet dictionary is read-only | 20 breeds, fixed at system initialization |
| TC-010 | Sequential actions sufficient | No distributed locking required |
| TC-011 | IAM-based connectivity (passwordless) | No hardcoded credentials; IAM roles and policies |

## 2.2 Organizational Constraints

| ID | Constraint | Rationale |
|----|-----------|-----------|
| OC-001 | 4-day hackathon timeline | All work must be completed within the event window |
| OC-002 | 1-2 person team | Limited parallelization of work |
| OC-003 | AI-assisted development required | Judges evaluate AI tool usage across the lifecycle |
| OC-004 | Live demo required | System must be accessible via public URL or run locally |

## 2.3 Conventions and Standards

| ID | Convention | Details |
|----|-----------|---------|
| CS-001 | arc42 + C4 for architecture documentation | Industry-standard templates |
| CS-002 | ADRs for decision tracking | Numbered ADR-NNN format |
| CS-003 | Markdown test cases | BDD/Gherkin format in docs/ |
| CS-004 | RESTful API design | JSON payloads, standard HTTP methods |
| CS-005 | Structured logging | JSON format, correlation IDs |
