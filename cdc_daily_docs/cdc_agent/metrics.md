# cdc.agent — Metrics & SLIs


### 2026-05-06 14:00

Metrics typically exposed by cdc.agent (or that operators care about):

- `cdc_agent_events_in_total` — events received.
- `cdc_agent_events_out_total` — events successfully forwarded.
- `cdc_agent_errors_total{reason}` — categorised failures.
- `cdc_agent_latency_seconds` — end-to-end processing histogram.
- `cdc_agent_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
