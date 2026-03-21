# arc42: 04 -- Solution Strategy

## 4.1 Technology Decisions


| Decision                   | Choice                          | Rationale                                                                        | ADR     |
| -------------------------- | ------------------------------- | -------------------------------------------------------------------------------- | ------- |
| Backend language/framework | .NET 10 LTS (C#)                | Strong typing, mature ecosystem, excellent AWS SDK support, LTS through Nov 2028 | ADR-001 |
| Container orchestration    | ECS Fargate                     | Serverless containers, no cluster management, auto-scaling (Trading API only)    | ADR-002 |
| Primary database           | RDS PostgreSQL                  | ACID transactions for financial operations, relational model fits trading domain | ADR-003 |
| Frontend framework         | React                           | Component-based, rich ecosystem, team expertise                                  | ADR-004 |
| API management             | AWS API Gateway                 | Managed REST + WebSocket, throttling, auth integration                           | ADR-005 |
| Authentication             | Amazon Cognito                  | AWS-native, JWT tokens, user pool management                                     | ADR-006 |
| Real-time communication    | Hybrid: REST polling + WebSocket notifications | REST polling (5s) for data; WebSocket only for trade notifications  | ADR-007, ADR-017 |
| Event-driven compute       | AWS Lambda                      | Lifecycle Engine tick processing, trade notification push                        | ADR-008, ADR-015 |
| Infrastructure as Code     | Terraform                       | Declarative, multi-provider, state management                                    | ADR-009 |
| CI/CD pipeline             | GitHub Actions                  | Repository-integrated, free tier, extensive marketplace                          | ADR-010 |
| Observability              | CloudWatch + X-Ray              | AWS-native, no additional tooling, unified view                                  | ADR-011 |
| Network topology           | VPC with public/private subnets | Defense in depth, service isolation                                              | ADR-012 |
| Lifecycle scheduling       | Lambda + EventBridge Scheduler  | Replaces ECS singleton; no idle compute, no coordination overhead                | ADR-015 |
| Pet aging model            | Absolute timestamp-based        | Age derived from `created_at`; no tick drift; deterministic                      | ADR-016 |


## 4.2 Top-Level Decomposition

The system follows a service-oriented architecture with a primary backend API service, a scheduled Lambda for lifecycle processing, and supporting AWS managed services.

### Service Boundaries


| Service                      | Responsibility                                                                                         | Compute                       | Communication                        |
| ---------------------------- | ------------------------------------------------------------------------------------------------------ | ----------------------------- | ------------------------------------ |
| **Trading API Service**      | All CRUD operations: auth proxy, supply, listings, bids, trades, portfolio, notifications, leaderboard. Also pushes WebSocket trade notifications directly. | ECS Fargate                   | REST API via API Gateway; WebSocket push via API Gateway Management API |
| **Lifecycle Lambda**         | Pet health/desirability variance, intrinsic value recalculation, age cache refresh                     | Lambda (EventBridge Scheduler, 1 min) | Reads/writes PostgreSQL only   |
| **React Frontend**           | Single Page Application with all trader views                                                          | S3 + CloudFront               | HTTPS (REST polling, 5s), WSS (trade notifications) |


### Data Ownership

The Trading API Service and Lifecycle Lambda share a single PostgreSQL database. This is a pragmatic decision for a hackathon project -- in a production system, each service would own its own data store (database-per-service pattern). The shared database approach avoids the complexity of eventual consistency and cross-service data synchronization within the tight hackathon timeline.

## 4.3 Quality Approach


| Quality Goal                    | Architectural Approach                                                                        |
| ------------------------------- | --------------------------------------------------------------------------------------------- |
| Real-time responsiveness (< 5s) | REST polling every 5s for data views; WebSocket push for trade notifications (< 1s)          |
| Data consistency                | Single PostgreSQL database with ACID transactions; serializable isolation for bid replacement |
| State durability                | RDS Multi-AZ deployment; automated backups; persistent storage for all state                  |
| Formula precision               | Single source of truth for formula in backend; frontend displays server-calculated values     |
| API performance (< 500ms p95)   | Dapper ORM for lean SQL queries; connection pooling; ALB health checks                        |


## 4.4 Architectural Patterns


| Pattern                           | Application                                                                      |
| --------------------------------- | -------------------------------------------------------------------------------- |
| **API Gateway pattern**           | All client requests routed through API Gateway for auth, throttling, and routing |
| **Backend for Frontend (BFF)**    | Trading API Service tailors responses for React frontend consumption             |
| **Database-per-team (pragmatic)** | Single shared database -- acceptable for hackathon; documented as technical debt |
| **Hybrid push/pull**              | WebSocket for trade notifications (push); REST polling for data views (pull)     |
| **Scheduled Lambda**              | EventBridge Scheduler triggers Lifecycle Lambda every 60s for pet value updates  |
| **Strangler fig (future)**        | Architecture allows extracting individual services later if needed               |

