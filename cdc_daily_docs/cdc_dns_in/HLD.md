# cdc.dns-in — High Level Design


## Iteration 2026-06-09 14:45

### Context
cdc.dns-in sits in the CDC pipeline as: **Ingestion (in)**.
Inputs: DNS log streams. Outputs: Kafka topics.

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
