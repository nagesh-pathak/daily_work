# cdc.infraservice — Metrics & SLIs


### 2026-05-29 11:00

Metrics typically exposed by cdc.infraservice (or that operators care about):

- `cdc_infraservice_events_in_total` — events received.
- `cdc_infraservice_events_out_total` — events successfully forwarded.
- `cdc_infraservice_errors_total{reason}` — categorised failures.
- `cdc_infraservice_latency_seconds` — end-to-end processing histogram.
- `cdc_infraservice_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
