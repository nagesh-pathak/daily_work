# cdc.splunkforwarderbase — Metrics & SLIs


### 2026-09-10 11:21

Metrics typically exposed by cdc.splunkforwarderbase (or that operators care about):

- `cdc_splunkforwarderbase_events_in_total` — events received.
- `cdc_splunkforwarderbase_events_out_total` — events successfully forwarded.
- `cdc_splunkforwarderbase_errors_total{reason}` — categorised failures.
- `cdc_splunkforwarderbase_latency_seconds` — end-to-end processing histogram.
- `cdc_splunkforwarderbase_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
