# cdc.automation.test — Metrics & SLIs


### 2026-09-16 14:12

Metrics typically exposed by cdc.automation.test (or that operators care about):

- `cdc_automation_test_events_in_total` — events received.
- `cdc_automation_test_events_out_total` — events successfully forwarded.
- `cdc_automation_test_errors_total{reason}` — categorised failures.
- `cdc_automation_test_latency_seconds` — end-to-end processing histogram.
- `cdc_automation_test_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
