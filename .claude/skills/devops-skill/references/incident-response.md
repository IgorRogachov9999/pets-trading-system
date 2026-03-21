# Incident Response & SRE Reference — Pets Trading System

## Table of Contents
1. [Severity Tiers](#1-severity-tiers)
2. [First Response Runbooks](#2-first-response-runbooks)
3. [ECS Rollback Procedure](#3-ecs-rollback-procedure)
4. [RDS Failover Procedure](#4-rds-failover-procedure)
5. [Lambda Incident Response](#5-lambda-incident-response)
6. [Postmortem Template](#6-postmortem-template)
7. [On-Call Checklist](#7-on-call-checklist)

---

## 1. Severity Tiers

| Severity | Definition | MTTA | MTTR | Postmortem |
|---|---|---|---|---|
| **SEV1** | Full outage OR financial data at risk (bids/trades broken) | 5 min | 30 min | Required, within 24 h |
| **SEV2** | Partial degradation — some traders affected, workaround exists | 15 min | 2 h | Required, within 48 h |
| **SEV3** | Minor issue, all core paths functional | Next business day | — | Optional |
| **SEV4** | Cosmetic / low impact | Scheduled ticket | — | No |

**SEV1 triggers:**
- API 5xx rate > 5% for 5 consecutive minutes
- RDS instance unavailable
- ECS service has 0 running tasks
- Financial mutation producing incorrect results (bid double-charge, lost funds)

---

## 2. First Response Runbooks

### High API Error Rate (5xx)

```bash
# 1. Identify scope
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name 5XXError \
  --dimensions Name=ApiName,Value=petstrading-prod \
  --start-time $(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 --statistics Average

# 2. Check ECS service health
aws ecs describe-services \
  --cluster petstrading-prod \
  --services trading-api \
  --query 'services[0].{running:runningCount,pending:pendingCount,desired:desiredCount}'

# 3. Check recent ECS events
aws ecs describe-services \
  --cluster petstrading-prod \
  --services trading-api \
  --query 'services[0].events[0:5]'

# 4. Check logs for errors (last 15 min)
aws logs filter-log-events \
  --log-group-name /ecs/petstrading-trading-api \
  --start-time $(($(date +%s%3N) - 900000)) \
  --filter-pattern '{ $.level = "ERROR" }' \
  --query 'events[*].message' \
  --output text

# 5. If recent deployment caused this — rollback (see §3)
# 6. If DB connectivity — check RDS (see §4)
```

### WebSocket Notifications Not Delivered

```bash
# Check DynamoDB connections table
aws dynamodb scan \
  --table-name petstrading-connections-prod \
  --select COUNT

# Check API Gateway WebSocket connections
aws apigatewayv2 get-connections \
  --api-id <WS_API_ID>

# Check Lambda for DynamoDB throttle errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ThrottledRequests \
  --dimensions Name=TableName,Value=petstrading-connections-prod \
  --start-time $(date -u -v-10M +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 --statistics Sum
```

---

## 3. ECS Rollback Procedure

```bash
# 1. Find the previous working task definition revision
aws ecs list-task-definitions \
  --family-prefix petstrading-trading-api-prod \
  --sort DESC \
  --query 'taskDefinitionArns[0:5]'

# 2. Roll back to previous revision (e.g., revision :5)
PREV_TASK_DEF="arn:aws:ecs:us-east-1:123456789:task-definition/petstrading-trading-api-prod:5"

aws ecs update-service \
  --cluster petstrading-prod \
  --service trading-api \
  --task-definition "$PREV_TASK_DEF" \
  --force-new-deployment

# 3. Wait for service to stabilize
aws ecs wait services-stable \
  --cluster petstrading-prod \
  --services trading-api

# 4. Verify error rate drops
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name 5XXError \
  --dimensions Name=ApiName,Value=petstrading-prod \
  --start-time $(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 --statistics Average
```

**Rollback time target:** < 5 minutes for ECS rolling rollback.

---

## 4. RDS Failover Procedure

RDS Multi-AZ handles automatic failover (typically < 60 s). During failover:

```bash
# 1. Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier petstrading-prod \
  --query 'DBInstances[0].{status:DBInstanceStatus,az:AvailabilityZone,multiAZ:MultiAZ}'

# 2. Monitor failover event
aws rds describe-events \
  --source-identifier petstrading-prod \
  --source-type db-instance \
  --duration 60 \
  --query 'Events[*].{time:Date,msg:Message}'

# 3. Check current endpoint (may change during failover)
aws rds describe-db-instances \
  --db-instance-identifier petstrading-prod \
  --query 'DBInstances[0].Endpoint'
```

Application uses DNS name (not IP), so it automatically reconnects to the new primary after failover. Npgsql connection pool will reconnect.

**If RDS does not auto-recover within 5 minutes:**
- Check if a snapshot restore is needed
- Run `terraform apply` to force desired state

---

## 5. Lambda Incident Response

```bash
# Check Lambda errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=petstrading-lifecycle-prod \
  --start-time $(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 --statistics Sum

# Check Lambda logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/petstrading-lifecycle-prod \
  --start-time $(($(date +%s%3N) - 1800000)) \
  --filter-pattern 'ERROR'

# If Lambda is timing out — check RDS connectivity from Lambda VPC
# Lambda must be in same VPC as RDS with access to private-db subnet security group

# Rollback Lambda to previous version
aws lambda list-versions-by-function \
  --function-name petstrading-lifecycle-prod \
  --query 'Versions[-3:]'

aws lambda update-function-code \
  --function-name petstrading-lifecycle-prod \
  --image-uri "<prev-ecr-image-uri>"
```

**Note:** Lambda failures only affect pet stat updates (health/desirability variance). The Trading API continues running. A missed tick is automatically caught up on the next 1-minute tick — it's idempotent.

---

## 6. Postmortem Template

```markdown
# Postmortem: [Brief Title]

**Date:** YYYY-MM-DD
**Severity:** SEV1 / SEV2
**Author:** @name
**Status:** Draft / In Review / Final

## Summary

One paragraph describing what happened, the impact, and how it was resolved.

## Impact

- Duration: X minutes
- Traders affected: ~N (estimate)
- Financial operations failed: Y bids / Z trades
- Error budget consumed: X% of monthly budget

## Timeline

| Time (UTC) | Event |
|---|---|
| 12:00 | Alarm fires: API 5xx > 1% |
| 12:03 | On-call acknowledges |
| 12:07 | Root cause identified: [description] |
| 12:15 | Mitigation applied: [action] |
| 12:22 | Error rate returns to normal |
| 12:30 | All-clear declared |

## Root Cause

[5-whys analysis]

1. Why? [immediate cause]
2. Why? [contributing factor]
3. Why? [systemic cause]

## What Went Well

- Detection was fast (alarm within 1 minute)
- Rollback procedure worked as expected

## What Could Improve

- Alert threshold was too high (missed initial degradation)
- No runbook for this failure mode

## Action Items

| Item | Owner | Due | Priority |
|---|---|---|---|
| Lower 5xx alarm threshold to 0.5% | @devops | 2026-03-28 | P1 |
| Add runbook for DB connection failures | @sre | 2026-04-04 | P2 |
```

---

## 7. On-Call Checklist

**Before your on-call rotation starts:**
- [ ] Verify CloudWatch alarms are active and SNS topic delivers to your phone
- [ ] Review the last 3 postmortems for known issues
- [ ] Confirm AWS console access and CLI credentials work
- [ ] Know the rollback procedure by heart (or have this doc bookmarked)

**During an incident:**
- [ ] Acknowledge the alarm within 5 minutes
- [ ] Declare severity and open a war-room channel (Slack `#incident-active`)
- [ ] Post initial update: "Investigating X, impact appears to be Y"
- [ ] Apply mitigation; do not investigate root cause under pressure — stabilize first
- [ ] Post resolution: "Resolved at HH:MM UTC. Root cause: [brief]. Postmortem to follow."

**After an incident:**
- [ ] Write postmortem within 24 h (SEV1) or 48 h (SEV2)
- [ ] File action items as tickets
- [ ] Update runbook if a new failure mode was encountered
