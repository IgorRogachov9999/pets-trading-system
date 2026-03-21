# arc42: 12 -- Glossary

## Domain Terms

| Term | Definition |
|------|-----------|
| **Trader** | Any registered user with an authenticated account; can buy, sell, and bid on pets |
| **Account** | A registered user's profile, identified by email and password |
| **availableCash** | Cash a trader can spend immediately (excludes locked cash) |
| **lockedCash** | Cash held against active bids; released when a bid is accepted, rejected, or withdrawn |
| **portfolioValue** | `availableCash + lockedCash + sum(intrinsicValue of all owned pets)` |
| **Top-Up** | A virtual cash addition that increases a trader's `availableCash` |
| **Withdrawal** | A virtual cash removal that decreases a trader's `availableCash` |
| **Listing** | An offer to sell a specific pet at a stated asking price |
| **Bid** | An offer to buy a listed pet at a stated price; only one active bid per listing (highest wins) |
| **intrinsicValue** | `BasePrice * (Health/100) * (Desirability/10) * (1 - Age/Lifespan)` |
| **Lifecycle Tick** | Periodic backend event (default: 60s) aging all pets and applying +/-5% variance |
| **Offline Tick Catch-Up** | Behaviour where a returning trader sees current pet values (updated by all ticks since logout) |
| **Expired** | Pet whose `age >= lifespan`; intrinsicValue = 0 but remains tradeable |
| **New Supply** | Fixed pool of fresh pets (3 per breed); separate from secondary market |
| **Secondary Market** | Peer-to-peer trading between traders via listings and bids |
| **Outbid** | Bid replaced by a higher bid; locked cash released automatically |
| **Pet Dictionary** | Read-only table of 20 breeds with base attributes (lifespan, desirability, maintenance, base price) |
| **Trade** | Completed transaction: pet ownership and cash transferred between two traders |

## Technical Terms

| Term | Definition |
|------|-----------|
| **ECS Fargate** | AWS Elastic Container Service with Fargate launch type; serverless container orchestration |
| **API Gateway** | AWS managed service for REST and WebSocket API management |
| **Cognito** | AWS identity service for user authentication and JWT token management |
| **RDS** | AWS Relational Database Service; managed PostgreSQL |
| **Multi-AZ** | Database deployment across two Availability Zones for high availability |
| **Dapper** | Lightweight .NET ORM for direct SQL execution with object mapping |
| **EventBridge** | AWS serverless event bus for decoupled service communication |
| **CloudFront** | AWS content delivery network (CDN) for frontend static assets |
| **WAF** | AWS Web Application Firewall for API protection |
| **VPC** | Virtual Private Cloud; isolated network within AWS |
| **VPC Endpoint** | PrivateLink connection to AWS services without traversing the internet |
| **NAT Gateway** | Network Address Translation; allows private subnet resources to access the internet |
| **ALB** | Application Load Balancer; Layer 7 load balancing for HTTP/HTTPS traffic |
| **IAM** | AWS Identity and Access Management; controls access to AWS resources |
| **ECR** | AWS Elastic Container Registry; Docker image repository |
| **X-Ray** | AWS distributed tracing service |
| **CloudWatch** | AWS monitoring service for logs, metrics, and alarms |
| **Terraform** | HashiCorp Infrastructure as Code tool |
| **SPA** | Single Page Application |
| **JWT** | JSON Web Token; used for authentication |
| **WSS** | WebSocket Secure; encrypted WebSocket protocol |
| **ACID** | Atomicity, Consistency, Isolation, Durability; database transaction properties |

## Acronyms

| Acronym | Expansion |
|---------|-----------|
| ADR | Architecture Decision Record |
| ALB | Application Load Balancer |
| API | Application Programming Interface |
| AZ | Availability Zone |
| BFF | Backend for Frontend |
| BRD | Business Requirements Document |
| CDN | Content Delivery Network |
| CI/CD | Continuous Integration / Continuous Deployment |
| CORS | Cross-Origin Resource Sharing |
| DDD | Domain-Driven Design |
| DNS | Domain Name System |
| ECR | Elastic Container Registry |
| ECS | Elastic Container Service |
| FR | Functional Requirement |
| IaC | Infrastructure as Code |
| IAM | Identity and Access Management |
| NFR | Non-Functional Requirement |
| RDS | Relational Database Service |
| REST | Representational State Transfer |
| SLI | Service Level Indicator |
| SLO | Service Level Objective |
| SPA | Single Page Application |
| SSE | Server-Sent Events |
| VPC | Virtual Private Cloud |
| WAF | Web Application Firewall |
