# cdc.kafka.flow.processor — Metrics & SLIs


### 2026-07-13 14:00

Metrics typically exposed by cdc.kafka.flow.processor (or that operators care about):

- `cdc_kafka_flow_processor_events_in_total` — events received.
- `cdc_kafka_flow_processor_events_out_total` — events successfully forwarded.
- `cdc_kafka_flow_processor_errors_total{reason}` — categorised failures.
- `cdc_kafka_flow_processor_latency_seconds` — end-to-end processing histogram.
- `cdc_kafka_flow_processor_queue_depth` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
