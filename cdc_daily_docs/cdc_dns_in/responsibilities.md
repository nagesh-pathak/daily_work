# cdc.dns-in — Responsibilities


### Added 2026-06-05 11:00

- Accept inbound events from the configured source.
- Validate and normalise payloads before publishing to Kafka.
- Apply backpressure / rate limiting when downstream lags.
- Emit per-tenant ingestion metrics and lag indicators.
- Handle reconnects and idempotent replays from upstream.
