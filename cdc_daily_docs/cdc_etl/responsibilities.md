# cdc.etl — Responsibilities


### Added 2026-07-06 17:07

- Read raw events from upstream Kafka topics.
- Apply enrichment (geo, threat-intel, tenant metadata).
- Drop or reroute events based on policy.
- Write processed events to downstream Kafka topics.
- Emit processor lag and per-rule counters.
