# cdc.siem-out — Metrics & SLIs


### 2026-07-30 17:02

Metrics typically exposed by cdc.siem-out (or that operators care about):

- `cdc_siem_out_events_in_total` — events received.
- `cdc_siem_out_events_out_total` — events successfully forwarded.
- `cdc_siem_out_errors_total{reason}` — categorised failures.
- `cdc_siem_out_latency_seconds` — end-to-end processing histogram.
- `cdc_siem_out_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
