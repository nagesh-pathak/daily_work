# cdc.grpc-out — Metrics & SLIs


### 2026-07-16 17:00

Metrics typically exposed by cdc.grpc-out (or that operators care about):

- `cdc_grpc_out_events_in_total` — events received.
- `cdc_grpc_out_events_out_total` — events successfully forwarded.
- `cdc_grpc_out_errors_total{reason}` — categorised failures.
- `cdc_grpc_out_latency_seconds` — end-to-end processing histogram.
- `cdc_grpc_out_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
