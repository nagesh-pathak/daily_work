# cdc.etl — Metrics & SLIs


### 2026-07-08 14:00

Metrics typically exposed by cdc.etl (or that operators care about):

- `cdc_etl_events_in_total` — events received.
- `cdc_etl_events_out_total` — events successfully forwarded.
- `cdc_etl_errors_total{reason}` — categorised failures.
- `cdc_etl_latency_seconds` — end-to-end processing histogram.
- `cdc_etl_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
