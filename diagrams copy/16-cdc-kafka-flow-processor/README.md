# CDC Kafka Flow Processor (cdc.kafka.flow.processor)

## Overview
Distributed Kafka message routing service. Cloud only. Routes messages from DataSource topics to flow-specific output topics. Consumer groups per DataSource, worker pool per partition, ecosystem filtering, dynamic topic management.

## Architecture

```
Kafka DataSource Topics → Consumer Groups → Worker Pool → Ecosystem Filter → Topic Router → Flow-Specific Output Topics
```

## Input Topics (DataSources)

| # | DataSource Topic | Description |
|---|-----------------|-------------|
| 1 | TD_QUERY_RESP_LOG | Threat Defense DNS query/response logs |
| 2 | TD_THREAT_FEEDS_HITS_LOG | Threat Defense threat feed hit logs |
| 3 | DDI_QUERY_RESP_LOG | DDI DNS query/response logs |
| 4 | DDI_DHCP_LEASE_LOG | DDI DHCP lease logs |
| 5 | AUDIT_LOG | Audit trail logs |
| 6 | SERVICE_LOG | Service operational logs |
| 7 | ATLAS_NOTIFICATIONS | Atlas notification events |
| 8 | SOC_INSIGHTS | SOC Insights v1 |
| 9 | SOC_INSIGHTS_V2 | SOC Insights v2 |

## Output Topics

| Attribute | Detail |
|-----------|--------|
| Pattern | `{accountId}_flowID{flowId}_{dataSourceName}` |
| Example | `acct123_flowID456_TD_QUERY_RESP_LOG` |
| Consumed by | cdc.grpc-in, cdc.http-out, cdc.syslog-out |

## Processing Pipeline

1. Consumer groups (1 per DataSource type) read from source topics
2. Worker pool processes messages concurrently (per-partition)
3. Ecosystem filter matches `account_id`
4. Router finds active flows for that account + DataSource
5. Produce to matching flow-specific output topics

## Topic Management (Manager)

- Creates topics when flow activated
- Deletes topics when flow deactivated
- Rebalances consumers on changes
- Monitors lag and health

## Flow Event Processing

- Subscribes to Dapr PubSub: `cdc-flow-{env}`

| Event | Action |
|-------|--------|
| FLOW_CREATE | Create topics + start consumers |
| FLOW_UPDATE | Reconfigure routing rules |
| FLOW_DELETE | Stop consumers + delete topics |

## Routing Rules

1. Match `account_id` from Kafka message
2. Find active flows for account
3. Check DataSource type subscription
4. Produce to matching flow topics (1 message → N flow topics)

## Scaling

- **Horizontal:** add processor instances, consumer groups auto-rebalance
- Cloud equivalent of Flume's on-prem routing function

## Dependencies

| Dependency | Purpose |
|------------|---------|
| CDC DataSource API | DataSource definitions and metadata |
| CDC Flow API | Flow configurations and routing rules |
| Identity Service | Account/ecosystem resolution |
| Kafka Cluster | Source/dest topics, admin operations |
| Dapr PubSub | Flow lifecycle events |
| Prometheus | Metrics collection and exposure |

## Key Packages

| Package | Responsibility |
|---------|---------------|
| `cmd/` | Service entrypoint and CLI |
| `pkg/processor/` | Message processing pipeline |
| `pkg/manager/` | Topic lifecycle management |
| `pkg/consumer/` | Kafka consumer group handling |
| `pkg/producer/` | Kafka producer and topic writing |
| `pkg/router/` | Flow-based message routing logic |
