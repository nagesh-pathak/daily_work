# cdc.common — Metrics & SLIs


### 2026-05-08 14:00

Metrics typically exposed by cdc.common (or that operators care about):

- `cdc_common_events_in_total` — events received.
- `cdc_common_events_out_total` — events successfully forwarded.
- `cdc_common_errors_total{reason}` — categorised failures.
- `cdc_common_latency_seconds` — end-to-end processing histogram.
- `cdc_common_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
