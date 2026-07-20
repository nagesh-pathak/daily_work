# cdc.http-out — Responsibilities


### Added 2026-07-20 14:00

- Consume from the appropriate Kafka topics for this destination type.
- Format payloads for the destination protocol.
- Authenticate to the destination (token / mTLS / API key).
- Apply retry, backoff and dead-letter handling on failures.
- Expose delivery latency, success-rate and queue-depth metrics.
