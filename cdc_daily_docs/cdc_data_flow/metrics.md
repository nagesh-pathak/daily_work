# cdc.data.flow — Metrics & SLIs


### 2026-05-19 11:00

Metrics typically exposed by cdc.data.flow (or that operators care about):

- `cdc_data_flow_events_in_total` — events received.
- `cdc_data_flow_events_out_total` — events successfully forwarded.
- `cdc_data_flow_errors_total{reason}` — categorised failures.
- `cdc_data_flow_latency_seconds` — end-to-end processing histogram.
- `cdc_data_flow_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
