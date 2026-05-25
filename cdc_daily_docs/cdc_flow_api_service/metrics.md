# cdc.flow.api.service — Metrics & SLIs


### 2026-05-25 14:00

Metrics typically exposed by cdc.flow.api.service (or that operators care about):

- `cdc_flow_api_service_events_in_total` — events received.
- `cdc_flow_api_service_events_out_total` — events successfully forwarded.
- `cdc_flow_api_service_errors_total{reason}` — categorised failures.
- `cdc_flow_api_service_latency_seconds` — end-to-end processing histogram.
- `cdc_flow_api_service_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
