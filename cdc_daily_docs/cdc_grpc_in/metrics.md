# cdc.grpc-in — Metrics & SLIs


### 2026-06-15 14:00

Metrics typically exposed by cdc.grpc-in (or that operators care about):

- `cdc_grpc_in_events_in_total` — events received.
- `cdc_grpc_in_events_out_total` — events successfully forwarded.
- `cdc_grpc_in_errors_total{reason}` — categorised failures.
- `cdc_grpc_in_latency_seconds` — end-to-end processing histogram.
- `cdc_grpc_in_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
