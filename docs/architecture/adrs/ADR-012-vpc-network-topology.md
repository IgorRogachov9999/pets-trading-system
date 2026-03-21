# ADR-012: VPC Network Topology Design

## Status
Accepted

## Context
The system runs multiple services (ECS, RDS, Lambda) that need network isolation, controlled internet access, and secure communication with AWS managed services. The architecture must follow AWS Well-Architected Framework security best practices: defense in depth, least privilege, and private-by-default networking.

## Decision
Deploy all workloads within a **custom VPC** (`10.0.0.0/16`) across **2 Availability Zones**, with **public subnets** (ALB, NAT), **private application subnets** (ECS Fargate), and **private database subnets** (RDS). Use **VPC Endpoints** for AWS service access to minimize NAT Gateway traffic.

### Network Layout

| Subnet Type | AZ-1 CIDR | AZ-2 CIDR | Resources |
|-------------|-----------|-----------|-----------|
| Public | `10.0.1.0/24` | `10.0.2.0/24` | ALB, NAT Gateway |
| Private App | `10.0.11.0/24` | `10.0.12.0/24` | ECS Fargate Tasks |
| Private DB | `10.0.21.0/24` | `10.0.22.0/24` | RDS PostgreSQL |

## Consequences
**Easier:**
- RDS and ECS tasks are not directly reachable from the internet
- Security groups provide stateful firewall rules at the instance level
- VPC Endpoints eliminate NAT Gateway costs for AWS API calls (Secrets Manager, CloudWatch, ECR, X-Ray)
- Multi-AZ deployment survives single AZ failure
- Clear separation of concerns between network tiers
- NAT Gateways in each AZ ensure outbound connectivity survives AZ failure

**Harder:**
- NAT Gateways add ~$32/month each (2 x $0.045/hr)
- VPC Endpoints have per-hour cost (~$0.01/hr each; 6 endpoints = ~$43/month)
- More Terraform resources to manage (subnets, route tables, security groups, endpoints)
- Development environment can use a simplified single-AZ layout to reduce cost

### Security Group Rules

| SG | Inbound | Outbound |
|----|---------|----------|
| sg-alb | 443 from 0.0.0.0/0 | 8080 to sg-ecs |
| sg-ecs | 8080 from sg-alb | 5432 to sg-rds; 443 to sg-vpce |
| sg-rds | 5432 from sg-ecs | Deny all |
| sg-vpce | 443 from sg-ecs | Deny all |

### VPC Endpoints

| Service | Type | Justification |
|---------|------|---------------|
| Secrets Manager | Interface | DB config retrieval without NAT |
| CloudWatch Logs | Interface | Log shipping without NAT |
| ECR API + DKR | Interface | Docker image pull without NAT |
| S3 | Gateway | ECR image layer storage (free) |
| X-Ray | Interface | Trace submission without NAT |
| Execute API | Interface | Lambda -> WebSocket push |

## Subnet Sizing Analysis

Each subnet tier was evaluated for IP address sufficiency given the serverless and autoscaled nature of the workloads.

### IP Consumption by Resource Type

| Resource | Subnet Tier | IPs Consumed | Notes |
|----------|------------|--------------|-------|
| ECS Fargate tasks | Private App | 1 IP per running task | awsvpc mode; peak ~20–30 tasks/AZ |
| AWS Lambda (VPC) | Private App | ~1–2 IPs per subnet | Hyperplane ENIs shared since 2020; concurrency-independent |
| RDS PostgreSQL Multi-AZ | Private DB | 2 IPs total | Primary (AZ-1) + standby (AZ-2) |
| ALB | Public | 8–50 IPs per AZ | Scales with traffic |
| NAT Gateway | Public | 1 IP per gateway | Fixed |

### Risk Assessment

| Risk | Likelihood | Impact |
|------|-----------|--------|
| IP exhaustion in app subnets | Very Low | Would block new ECS tasks from launching |
| IP exhaustion in DB subnets | None | RDS uses 1–2 IPs |
| IP exhaustion in public subnets | Very Low | Would impair ALB scaling |
| Wasted IP space | Certain but irrelevant | Zero cost impact within /16 |

### Why Uniform `/24` Is Appropriate

- **No cost to waste**: Private IPs in a VPC are free. The /16 provides 65,536 addresses; 6 x /24 subnets consume only 1,536 (2.3%).
- **App tier is correctly sized**: /24 gives 251 usable IPs per AZ -- 8-50x headroom over peak ECS task counts.
- **Lambda is a non-issue**: AWS Hyperplane ENIs (introduced 2020) mean Lambda consumes ~1-2 IPs per subnet regardless of concurrency.
- **DB tier is oversized but harmlessly so**: Shrinking to /27 or /28 would save addresses nobody needs while making the CIDR scheme non-uniform and complicating Terraform modules.
- **Uniform sizing simplifies IaC**: One subnet size variable, no per-tier CIDR overrides in Terraform.
- **Future-proofing**: Additional services (Redis, OpenSearch, extra microservices) absorb into existing /24 headroom without a CIDR redesign.

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Default VPC** | No subnet isolation; everything in public subnets; security risk |
| **Single AZ** | No fault tolerance; RDS Multi-AZ requires subnets in 2 AZs |
| **3 AZs** | Increased cost (3 NAT Gateways); 2 AZs sufficient for hackathon HA |
| **No NAT Gateway (all VPC endpoints)** | Some AWS services do not support VPC endpoints; outbound internet needed for edge cases |
| **Transit Gateway** | Overkill for single-VPC architecture |
