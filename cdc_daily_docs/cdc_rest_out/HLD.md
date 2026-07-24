# cdc.rest-out — High Level Design


## Iteration 2026-07-24 18:05

### Context
cdc.rest-out sits in the CDC pipeline as: **Egress (out)**.
Inputs: Kafka topics. Outputs: Customer REST APIs.

### Goals
- Reliable, ordered delivery between input and output.
- Per-tenant isolation and quotas.
- Observability first: metrics, traces, structured logs.
- Graceful degradation under partial failure.

### Non-goals
- Long-term storage of events (handled by reporting/analytics tier).
- Tenant lifecycle management (handled by onboarding plane).

### Key components (this iteration)
- Connection / consumer layer.
- Transformation pipeline.
- Output dispatcher with retry policy.
- Health & readiness probes.

### Open questions / TODO
- Confirm Kafka consumer-group naming convention.
- Document exact retry/backoff defaults.
