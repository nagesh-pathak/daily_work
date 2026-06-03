# cdc.onboarding — Metrics & SLIs


### 2026-06-03 14:00

Metrics typically exposed by cdc.onboarding (or that operators care about):

- `cdc_onboarding_events_in_total` — events received.
- `cdc_onboarding_events_out_total` — events successfully forwarded.
- `cdc_onboarding_errors_total{reason}` — categorised failures.
- `cdc_onboarding_latency_seconds` — end-to-end processing histogram.
- `cdc_onboarding_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
