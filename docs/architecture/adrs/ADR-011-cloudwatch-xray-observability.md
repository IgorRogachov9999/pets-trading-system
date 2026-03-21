# ADR-011: CloudWatch + X-Ray for Observability

## Status
Accepted

## Context
The hackathon scoring matrix includes bonus points for operational awareness (logs, metrics, monitoring). The system needs structured logging, basic metrics (API latency, error rates), and distributed tracing across ECS services and Lambda functions. The observability stack should require minimal setup and integrate natively with all AWS services used.

## Decision
Use **Amazon CloudWatch** for logs and metrics, and **AWS X-Ray** for distributed tracing. No third-party observability tools.

## Consequences
**Easier:**
- Zero additional infrastructure to deploy (AWS-managed)
- ECS Fargate natively streams container logs to CloudWatch via awslogs driver
- Lambda automatically integrates with CloudWatch Logs
- X-Ray SDK for .NET provides automatic instrumentation of HTTP calls and SQL queries
- CloudWatch Alarms can trigger on error rates or latency thresholds
- CloudWatch Insights for ad-hoc log queries
- API Gateway access logs and execution logs to CloudWatch
- Unified AWS console for all observability data

**Harder:**
- CloudWatch dashboards are less feature-rich than Grafana
- X-Ray sampling may miss infrequent events (configurable sampling rules)
- No built-in anomaly detection beyond basic alarms
- CloudWatch Logs query language is less powerful than Elasticsearch
- Cost can increase with high log volume (not a concern for hackathon)

### Key Metrics to Monitor

| Metric | Source | Alarm Threshold |
|--------|--------|----------------|
| API Gateway 5xx rate | API Gateway metrics | > 5% for 2 minutes |
| API Gateway latency p95 | API Gateway metrics | > 500ms for 5 minutes |
| ECS task health | ECS health checks | Any unhealthy task |
| RDS CPU utilization | RDS metrics | > 80% for 5 minutes |
| RDS free storage | RDS metrics | < 5 GB |
| Lambda errors | Lambda metrics | > 0 for 5 minutes |
| Lambda duration p95 | Lambda metrics | > 5 seconds |
| Tick loop interval | Custom metric | Deviation > 10% from configured interval |

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Datadog** | Third-party service; cost; requires agent installation; over-engineered for hackathon |
| **Prometheus + Grafana** | Self-hosted; requires ECS services for Prometheus and Grafana; operational overhead |
| **New Relic** | External dependency; setup time; cost |
| **ELK Stack** | Self-hosted; significant infrastructure; maintenance overhead |
