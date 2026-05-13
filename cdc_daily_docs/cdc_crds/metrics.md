# cdc.crds — Metrics & SLIs


### 2026-05-13 17:00

Metrics typically exposed by cdc.crds (or that operators care about):

- `cdc_crds_events_in_total` — events received.
- `cdc_crds_events_out_total` — events successfully forwarded.
- `cdc_crds_errors_total{reason}` — categorised failures.
- `cdc_crds_latency_seconds` — end-to-end processing histogram.
- `cdc_crds_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
