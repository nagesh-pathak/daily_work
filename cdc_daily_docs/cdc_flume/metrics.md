# cdc.flume — Metrics & SLIs


### 2026-07-03 11:00

Metrics typically exposed by cdc.flume (or that operators care about):

- `cdc_flume_events_in_total` — events received.
- `cdc_flume_events_out_total` — events successfully forwarded.
- `cdc_flume_errors_total{reason}` — categorised failures.
- `cdc_flume_latency_seconds` — end-to-end processing histogram.
- `cdc_flume_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
