# Monitoring & Observability Reference — Pets Trading System

## Table of Contents
1. [CloudWatch Log Groups](#1-cloudwatch-log-groups)
2. [CloudWatch Alarms](#2-cloudwatch-alarms)
3. [CloudWatch Dashboard](#3-cloudwatch-dashboard)
4. [AWS X-Ray Tracing](#4-aws-x-ray-tracing)
5. [SLO Definitions](#5-slo-definitions)
6. [Business Metrics](#6-business-metrics)

---

## 1. CloudWatch Log Groups

All application logs go to CloudWatch Logs as structured JSON. Log groups to create in Terraform:

```hcl
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/petstrading-trading-api"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/petstrading-lifecycle"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/petstrading-prod/postgresql"
  retention_in_days = 7
}
```

**Required fields in every application log entry:**
```json
{
  "timestamp": "2026-03-21T12:00:00.000Z",
  "level": "INFO",
  "message": "bid.placed",
  "traceId": "1-xxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx",
  "requestId": "abc-123",
  "traderId": "trader-uuid",
  "listingId": "listing-uuid",
  "durationMs": 45
}
```

Never log: JWT tokens, passwords, PII (email, full name), connection strings.

---

## 2. CloudWatch Alarms

### Required alarms (SEV1 — page immediately)

| Alarm | Metric | Threshold | Period |
|---|---|---|---|
| API 5xx rate | `AWS/ApiGateway 5XXError` | > 1% | 5 min |
| API P99 latency | `AWS/ApiGateway Latency p99` | > 1000 ms | 5 min |
| Lambda errors | `AWS/Lambda Errors` | > 0 | 1 min |
| ECS service unstable | `AWS/ECS RunningTaskCount` | < 1 | 1 min |
| RDS connection refused | Custom: failed health checks | > 3 | 1 min |

### Required alarms (SEV2 — warn)

| Alarm | Metric | Threshold | Period |
|---|---|---|---|
| RDS CPU | `AWS/RDS CPUUtilization` | > 80% | 10 min |
| RDS connections | `AWS/RDS DatabaseConnections` | > 80% of max | 5 min |
| DynamoDB throttles | `AWS/DynamoDB ThrottledRequests` | > 0 | 5 min |
| ECS CPU | `AWS/ECS CPUUtilization` | > 75% | 5 min |
| Lambda duration | `AWS/Lambda Duration p99` | > 8000 ms | 5 min |

```hcl
# Terraform example
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "petstrading-prod-api-5xx-rate"
  alarm_description   = "API 5xx error rate > 1% for 5 minutes — SEV1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0.01
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    ApiName = "petstrading-prod"
    Stage   = "v1"
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
```

---

## 3. CloudWatch Dashboard

```hcl
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "petstrading-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: API health
      {
        type = "metric"; x = 0; y = 0; width = 8; height = 6
        properties = {
          title   = "API Request Rate"
          metrics = [["AWS/ApiGateway", "Count", "ApiName", "petstrading-prod"]]
          period  = 60; stat = "Sum"; view = "timeSeries"
        }
      },
      {
        type = "metric"; x = 8; y = 0; width = 8; height = 6
        properties = {
          title   = "API Error Rate"
          metrics = [["AWS/ApiGateway", "5XXError", "ApiName", "petstrading-prod"]]
          period  = 60; stat = "Average"; view = "timeSeries"
        }
      },
      {
        type = "metric"; x = 16; y = 0; width = 8; height = 6
        properties = {
          title   = "API Latency (P50 / P95 / P99)"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", "petstrading-prod", { stat = "p50", label = "P50" }],
            ["...", { stat = "p95", label = "P95" }],
            ["...", { stat = "p99", label = "P99" }]
          ]
          period = 60; view = "timeSeries"
        }
      },
      # Row 2: ECS + RDS
      {
        type = "metric"; x = 0; y = 6; width = 12; height = 6
        properties = {
          title   = "ECS CPU / Memory"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", "petstrading-prod", "ServiceName", "trading-api"],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", "petstrading-prod", "ServiceName", "trading-api"]
          ]
          period = 60; stat = "Average"; view = "timeSeries"
        }
      },
      {
        type = "metric"; x = 12; y = 6; width = 12; height = 6
        properties = {
          title   = "RDS CPU / Connections"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "petstrading-prod"],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "petstrading-prod"]
          ]
          period = 60; stat = "Average"; view = "timeSeries"
        }
      },
      # Row 3: Lambda + DynamoDB
      {
        type = "metric"; x = 0; y = 12; width = 12; height = 6
        properties = {
          title   = "Lambda Duration / Errors"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "petstrading-lifecycle-prod", { stat = "p99" }],
            ["AWS/Lambda", "Errors", "FunctionName", "petstrading-lifecycle-prod"]
          ]
          period = 60; view = "timeSeries"
        }
      },
      {
        type = "metric"; x = 12; y = 12; width = 12; height = 6
        properties = {
          title   = "DynamoDB Read/Write / Throttles"
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "petstrading-connections-prod"],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", "petstrading-connections-prod"],
            ["AWS/DynamoDB", "ThrottledRequests", "TableName", "petstrading-connections-prod"]
          ]
          period = 60; stat = "Sum"; view = "timeSeries"
        }
      }
    ]
  })
}
```

---

## 4. AWS X-Ray Tracing

X-Ray traces the full request path: API Gateway → ECS → RDS queries.

**Enable on API Gateway (Terraform):**
```hcl
resource "aws_api_gateway_stage" "main" {
  # ...
  xray_tracing_enabled = true
}
```

**Enable on Lambda (Terraform):**
```hcl
resource "aws_lambda_function" "lifecycle" {
  # ...
  tracing_config { mode = "Active" }
}
```

**.NET SDK setup (ECS app startup):**
```csharp
// Program.cs
builder.Services.AddAWSXRayRecorder();
builder.Services.AddXRay();

app.UseXRay("petstrading-trading-api");   // creates root segment per request
```

**Instrument Dapper calls as X-Ray subsegments:**
```csharp
// Infrastructure/Persistence/BaseRepository.cs
protected async Task<T?> QuerySingleAsync<T>(
    string sql, object? param, IDbTransaction? tx, CancellationToken ct)
{
    using var subsegment = AWSXRayRecorder.Instance.BeginSubsegment("PostgreSQL");
    try
    {
        subsegment.AddAnnotation("sql.query", sql[..Math.Min(100, sql.Length)]);
        return await connection.QuerySingleOrDefaultAsync<T>(
            new CommandDefinition(sql, param, tx, cancellationToken: ct));
    }
    catch (Exception ex)
    {
        subsegment.AddException(ex);
        throw;
    }
    finally
    {
        AWSXRayRecorder.Instance.EndSubsegment();
    }
}
```

---

## 5. SLO Definitions

| SLO | Target | Measurement Window |
|---|---|---|
| API availability | 99.9% | 30-day rolling |
| API P95 latency ≤ 200 ms | 95% of requests | 30-day rolling |
| API P99 latency ≤ 1000 ms | 99% of requests | 30-day rolling |
| Lambda tick success rate | 99% | 7-day rolling |
| WebSocket notification delivery | 95% | 7-day rolling |

**Error budget for 99.9% (30 days):** ~43 minutes of downtime allowed.

When error budget drops below 25%:
- Halt non-critical feature deployments
- Daily review of reliability metrics

When error budget is exhausted:
- Full feature freeze until budget is restored
- SEV1-level incident investigation

---

## 6. Business Metrics

Emit these as CloudWatch custom metrics from the Trading API using the `Amazon.CloudWatch` SDK:

| Metric | Unit | Dimension |
|---|---|---|
| `TradingSystem/BidsPlaced` | Count | Environment |
| `TradingSystem/TradesExecuted` | Count | Environment |
| `TradingSystem/TradeValue` | None (decimal) | Environment |
| `TradingSystem/ActiveListings` | Count | Environment |
| `TradingSystem/ActiveBids` | Count | Environment |
| `TradingSystem/WebSocketConnections` | Count | Environment |

```csharp
// After a successful trade in the command handler
await _cloudWatch.PutMetricDataAsync(new PutMetricDataRequest
{
    Namespace = "TradingSystem",
    MetricData =
    [
        new MetricDatum
        {
            MetricName = "TradesExecuted",
            Value      = 1,
            Unit       = StandardUnit.Count,
            Dimensions = [new Dimension { Name = "Environment", Value = _env }]
        },
        new MetricDatum
        {
            MetricName = "TradeValue",
            Value      = (double)tradeAmount,
            Unit       = StandardUnit.None,
            Dimensions = [new Dimension { Name = "Environment", Value = _env }]
        }
    ]
});
```
