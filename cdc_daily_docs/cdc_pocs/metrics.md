# cdc.pocs — Metrics & SLIs


### 2026-09-21 17:01

Metrics typically exposed by cdc.pocs (or that operators care about):

- `cdc_pocs_events_in_total` — events received.
- `cdc_pocs_events_out_total` — events successfully forwarded.
- `cdc_pocs_errors_total{reason}` — categorised failures.
- `cdc_pocs_latency_seconds` — end-to-end processing histogram.
- `cdc_pocs_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
