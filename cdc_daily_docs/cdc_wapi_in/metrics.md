# cdc.wapi-in — Metrics & SLIs


### 2026-06-29 17:30

Metrics typically exposed by cdc.wapi-in (or that operators care about):

- `cdc_wapi_in_events_in_total` — events received.
- `cdc_wapi_in_events_out_total` — events successfully forwarded.
- `cdc_wapi_in_errors_total{reason}` — categorised failures.
- `cdc_wapi_in_latency_seconds` — end-to-end processing histogram.
- `cdc_wapi_in_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
