# arc42: 10 -- Quality Requirements

## 10.1 Quality Tree

```
Quality
├── Reliability
│   ├── State Durability (NFR-004): All state persists across server restarts
│   ├── Data Consistency (NFR-007): Portfolio values identical across all views
│   └── Formula Precision (NFR-008): Intrinsic value divergence < $0.01
│
├── Performance
│   ├── Real-Time Latency (NFR-001): UI reflects changes within 2 seconds
│   ├── API Response Time (NFR-006): < 500ms p95
│   └── Tick Throughput: Process 60 pets in < 5 seconds per tick
│
├── Usability
│   ├── View Completeness: All 5 required views accessible
│   ├── Session Continuity: State restored on login including offline ticks
│   └── Notification Clarity: 5 types with pet, price, counterparty
│
├── Security
│   ├── Auth Security (NFR-009): Hashed passwords, invalidated tokens
│   ├── Session Expiry (NFR-010): 24h inactivity timeout
│   └── Network Isolation: Private subnets, security groups, WAF
│
└── Operability
    ├── Deployment: Accessible during demo (NFR-005)
    ├── Tick Configurability (NFR-003): Interval via environment variable
    └── Observability: Structured logs, traces, metrics
```

## 10.2 Quality Scenarios

| ID | Quality | Scenario | Stimulus | Expected Response | Metric |
|----|---------|----------|----------|------------------|--------|
| QS-001 | Real-time latency | Trader accepts a bid | Trade execution event | All affected panels refresh | <= 2 seconds |
| QS-002 | Real-time latency | Lifecycle tick completes | Tick event published | All connected clients receive updated values | <= 2 seconds |
| QS-003 | Data consistency | Judge checks portfolio on panel vs leaderboard | View two different pages | Values are identical | Exact match |
| QS-004 | Formula precision | Judge verifies intrinsic value calculation | Select random pet, compute manually | Backend value matches manual calculation | < $0.01 divergence |
| QS-005 | State durability | Server restarts during demo | ECS task restart | Trader logs in and sees all previous state | No data loss |
| QS-006 | State durability | Trader logs out, 5 ticks occur, trader logs back in | Login request | Pet values reflect all 5 ticks | Values are current |
| QS-007 | API performance | 10 concurrent traders placing bids | Multiple API requests | All respond successfully | < 500ms p95 |
| QS-008 | Security | Trader attempts to access another trader's data | API request with valid JWT | 403 Forbidden | Blocked |
| QS-009 | Tick configurability | Judge requests 10-second ticks | Change env var, restart | Ticks fire every 10 seconds | Configurable |
| QS-010 | Concurrent users | 10+ traders authenticated simultaneously | Concurrent sessions | All sessions function independently | No interference |

## 10.3 SLIs and SLOs

| SLI | Measurement | SLO Target | Error Budget |
|-----|------------|------------|-------------|
| API availability | Successful responses / total requests | 99.5% (hackathon) | 0.5% |
| API latency (p95) | Time from request to response | < 500ms | 5% of requests may exceed |
| Real-time push latency | Time from event to client receipt | < 2 seconds | 2% of events may exceed |
| Trade execution success | Successful trades / attempted trades | 99.9% | 0.1% |
| Tick execution success | Successful ticks / scheduled ticks | 99% | 1% (auto-recovery on next tick) |
| Data consistency | Cross-view portfolio value match | 100% | 0% (hard requirement) |

## 10.4 Fitness Functions

| Function | What It Tests | How to Run |
|----------|--------------|------------|
| Portfolio consistency check | Query portfolio from trader panel and leaderboard endpoints; compare | Automated test after each trade |
| Formula accuracy test | Calculate intrinsic value for 20 sample scenarios; compare with API | Unit test + integration test |
| Real-time latency probe | Measure time from bid placement to WebSocket notification delivery | End-to-end test with timestamps |
| Tick interval accuracy | Measure actual tick intervals over 10 cycles | Log analysis |
| State persistence test | Write state, restart ECS task, verify state restored | Integration test |
