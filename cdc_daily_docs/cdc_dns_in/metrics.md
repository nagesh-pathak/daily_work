# cdc.dns-in — Metrics & SLIs


### 2026-06-10 11:00

Metrics typically exposed by cdc.dns-in (or that operators care about):

- `cdc_dns_in_events_in_total` — events received.
- `cdc_dns_in_events_out_total` — events successfully forwarded.
- `cdc_dns_in_errors_total{reason}` — categorised failures.
- `cdc_dns_in_latency_seconds` — end-to-end processing histogram.
- `cdc_dns_in_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
