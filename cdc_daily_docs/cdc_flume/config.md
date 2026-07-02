# cdc.flume — Configuration notes


### 2026-07-02 17:01

Common environment variables expected by cdc.flume:

| Variable | Purpose |
|----------|---------|
| `LOG_LEVEL` | debug/info/warn/error |
| `KAFKA_BROKERS` | comma-separated broker list |
| `KAFKA_TOPIC` | input/output topic for this service |
| `KAFKA_GROUP_ID` | consumer group (egress / processor only) |
| `METRICS_PORT` | Prometheus scrape port |
| `HEALTH_PORT` | health/readiness port |
| `TENANT_FILTER` | optional tenant allow-list |

> Verify against the service's actual `config.yaml` / Helm values before relying on this list.
