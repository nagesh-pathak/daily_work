# cdc.appbase — Metrics & SLIs


### 2026-05-07 11:24

Metrics typically exposed by cdc.appbase (or that operators care about):

- `cdc_appbase_events_in_total` — events received.
- `cdc_appbase_events_out_total` — events successfully forwarded.
- `cdc_appbase_errors_total{reason}` — categorised failures.
- `cdc_appbase_latency_seconds` — end-to-end processing histogram.
- `cdc_appbase_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
