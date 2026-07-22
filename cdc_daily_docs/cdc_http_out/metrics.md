# cdc.http-out — Metrics & SLIs


### 2026-07-22 14:08

Metrics typically exposed by cdc.http-out (or that operators care about):

- `cdc_http_out_events_in_total` — events received.
- `cdc_http_out_events_out_total` — events successfully forwarded.
- `cdc_http_out_errors_total{reason}` — categorised failures.
- `cdc_http_out_latency_seconds` — end-to-end processing histogram.
- `cdc_http_out_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
