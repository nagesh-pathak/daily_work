# cdc.api — Metrics & SLIs


### 2026-05-07 11:13

Metrics typically exposed by cdc.api (or that operators care about):

- `cdc_api_events_in_total` — events received.
- `cdc_api_events_out_total` — events successfully forwarded.
- `cdc_api_errors_total{reason}` — categorised failures.
- `cdc_api_latency_seconds` — end-to-end processing histogram.
- `cdc_api_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
