# Data Exporter Kafka — Cloud gRPC Data Export Server

## Purpose

Data Exporter Kafka (DEK) is a cloud-side **gRPC streaming server** that exports CDC event data from Kafka to on-premises NIOS hosts. It acts as the bridge between the cloud Kafka event bus and on-prem `cdc.grpc-in` clients, delivering security telemetry data over authenticated, chunked gRPC streams.

Key capabilities:
- **Server-streaming gRPC**: On-prem hosts connect and receive a continuous stream of events
- **Per-OPHID Kafka consumer groups**: Each on-prem host gets its own isolated Kafka consumer group
- **Chunked message delivery**: Large messages split into 3.5 MB chunks with sequence numbering
- **Keep-alive mechanism**: 30-second periodic pings maintain long-lived connections
- **OPHID mTLS authentication**: On-prem hosts authenticate via mutual TLS certificates
- **9 supported data types**: DNS, DHCP, audit, threat intelligence, SOC insights, and more
- **S3 log export**: Optional pub/sub-driven file uploads to S3 buckets

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                    CLOUD (Kubernetes)                                 │
│                                                                      │
│  Kafka Cluster                                                       │
│  ┌─────────────────────────────────────────┐                         │
│  │ {acctId}_flowID{id}_{dataType} topics   │                         │
│  └──────────────────┬──────────────────────┘                         │
│                     │                                                │
│  ┌──────────────────▼──────────────────────┐                         │
│  │     Data Exporter Kafka (3 replicas)    │                         │
│  │                                         │                         │
│  │  ┌─────────────────────────────────┐    │                         │
│  │  │ Per-OPHID Kafka Consumer Group  │    │                         │
│  │  │ GroupID: dek-{ophid}            │    │                         │
│  │  └────────────┬────────────────────┘    │                         │
│  │               │                         │                         │
│  │  ┌────────────▼────────────────────┐    │                         │
│  │  │ gRPC Server (port 8443/9090)    │    │  :8080 /metrics         │
│  │  │ DataReq() → stream DataResponse │    │  :8081 /health, /ready  │
│  │  └────────────┬────────────────────┘    │                         │
│  └───────────────┼─────────────────────────┘                         │
│                  │                                                   │
│  NGINX Ingress (sticky sessions via $remote_dn)                      │
│  mTLS termination (aws-pca-onprem cert)                              │
│  Auth URL: identity-api/v2/session/verify                            │
└──────────────────┼───────────────────────────────────────────────────┘
                   │ gRPC stream (TLS)
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    ON-PREM (NIOS Host)                                │
│                                                                      │
│  cdc.grpc-in ◄── DataResponse stream (chunked messages + keepalive)  │
│       │                                                              │
│       ▼                                                              │
│  Reassemble chunks → Process events → Forward to destinations        │
└──────────────────────────────────────────────────────────────────────┘
```

### Connection Lifecycle

1. **Connect**: On-prem host calls `DataReq()` with OPHID and flow IDs (encoded as `flowID << 32 | dataType`)
2. **Authenticate**: OPHID extracted from gRPC metadata; account info from Athena JWT claims
3. **Deduplicate**: If OPHID already connected, previous connection is terminated
4. **Consume**: Per-OPHID Kafka consumer group created with topics derived from flow IDs
5. **Stream**: Messages sent as chunked `DataResponse` with START/CONTINUE/END status
6. **Keep-alive**: Every 30s, a `KEEPALIVE` message sent to prevent connection timeout
7. **Disconnect**: On context cancellation or error, consumer group closed and connection cleaned up

### Chunked Message Streaming

Messages exceeding the chunk size (default: 3,670,016 bytes ≈ 3.5 MB) are split:

```
Message (10 MB)
├── Chunk 0: status=START,  seqNum=0, dataBytes[0..3.5MB]
├── Chunk 1: status=CONTINUE, seqNum=1, dataBytes[3.5MB..7MB]
└── Chunk 2: status=END,    seqNum=2, dataBytes[7MB..10MB]

Small message (< 3.5 MB)
└── Chunk 0: status=END, seqNum=0, dataBytes[0..N]
```

Each `DataResponse` includes: `reqType`, `sequenceNumber`, `offset`, `msgSize`, `remainingSize`, `transferredBytes`, `flowid`.

## Data Flow

### Supported Data Types (9)

| Enum Value | Data Type | Description |
|------------|-----------|-------------|
| 0 | `TD_QUERY_RESP_LOG` | Threat Defense DNS query response logs |
| 1 | `TD_THREAT_FEEDS_HITS_LOG` | Threat feeds hit logs |
| 2 | `DDI_QUERY_RESP_LOG` | DDI DNS query response logs |
| 3 | `DDI_DHCP_LEASE_LOG` | DDI DHCP lease logs |
| 5 | `AUDIT_LOG` | Platform audit logs |
| 6 | `ATLAS_NOTIFICATIONS` | Atlas platform notifications |
| 7 | `SERVICE_LOG` | Service operation logs |
| 8 | `SOC_INSIGHTS` | Security Operations Center insights |
| 9 | `SOC_INSIGHTS_V2` | SOC insights (v2 schema) |

### Kafka Topic Format
```
{accountId}_flowID{flowId}_{dataType}
```
Example: `acct123_flowID456_TD_QUERY_RESP_LOG`

### Flow ID Encoding

On-prem clients send flow IDs as `int64` values encoding both flow ID and data type:
```
flowid = (actualFlowID << 32) | dataType
```
The server decodes this to build the topic list for the Kafka consumer.

### gRPC Protocol (service.proto)

```protobuf
service DataExporterKafka {
  rpc DataReq (DataRequest) returns (stream DataResponse) {}
  rpc AckDataReceived (AckData) returns (google.protobuf.Empty) {}
}

message DataRequest {
  string ophid = 1;
  repeated int64 flowid = 2;   // Encoded as (FlowID << 32) | DataType
  string destination = 3;
}

message DataResponse {
  requestType reqType = 1;     // Data type or KEEPALIVE
  msgTransferStatus status = 3; // START, CONTINUE, END
  int32 sequenceNumber = 4;
  int32 msgSize = 5;
  bytes dataBytes = 8;
  int32 flowid = 9;
}
```

### S3 Log Export (Optional)

When `pubsub.enable=true`, DEK also runs a **Streamer Manager** that:
1. Subscribes to a pub/sub topic (`cdc-kafka-flow-export`) for file export commands
2. Processes `CREATED`/`DELETED`/`EXISTS` actions
3. Creates per-topic Kafka consumers and uploads messages to S3 buckets
4. Uses AWS S3 SDK for file upload with timestamp-based naming

## Key Files & Directory Structure

```
data.exporter.kafka/
├── cmd/
│   ├── server/main.go             # Main entry point — gRPC + HTTP servers
│   └── client/                    # Test client
├── pkg/
│   ├── svc/
│   │   └── zserver.go             # Core gRPC server — DataReq, connection mgmt, chunking
│   ├── pb/
│   │   ├── service.proto          # Protobuf definitions (9 data types, DataRequest/Response)
│   │   ├── service.pb.go          # Generated Go code
│   │   └── service.pb.validate.go # Validation code
│   ├── kafkaconsumer/
│   │   └── consumer.go            # Sarama-based Kafka consumer group
│   ├── flowtopic/
│   │   └── flowtopic.go           # Topic name builder/parser ({acctId}_flowID{id}_{type})
│   ├── streamer/
│   │   ├── manager.go             # Pub/sub event manager for S3 log exports
│   │   └── streamer.go            # Per-topic Kafka→S3 streamer
│   └── fileuploader/              # S3 file upload abstraction
├── helm/data-exporter-kafka/
│   ├── Chart.yaml                 # Helm chart v0.1.0
│   ├── values.yaml                # Default values (3 replicas, ports, Kafka config)
│   └── templates/
│       ├── svc-manifest.yaml      # Deployment + Service (3 replicas, anti-affinity)
│       ├── ingress-rule.yaml      # NGINX ingress with sticky sessions
│       ├── hpa.yaml               # Horizontal Pod Autoscaler
│       ├── pdb.yaml               # Pod Disruption Budget
│       └── dashboard.yaml         # Grafana monitoring dashboard
├── docker/                        # Dockerfiles
├── deploy/                        # Deployment manifests
└── docs/                          # Documentation
```

## Configuration

### Server Configuration
| Config Key | Description | Default |
|------------|-------------|---------|
| `server.address` | gRPC listen address | `""` |
| `server.port` | gRPC listen port | `9090` |
| `logging.level` | Log level | `debug` |
| `consumer.brokers` | Kafka broker addresses | — |
| `consumer.rack.enabled` | Kafka rack-aware consumption | `false` |
| `consumer.session.timeout` | Kafka session timeout | `60s` |
| `consumer.group.rebalance.timeout` | Rebalance timeout | `10s` |
| `consumer.group.read.timeout` | Read timeout | `30s` |
| `consumer.fetch.maxMessages` | Max fetch messages | — |
| `flowTopic.chunkSize` | Message chunk size (bytes) | `3670016` (3.5 MB) |
| `flowTopic.keepAlive` | Keep-alive interval | `30s` |

### Pub/Sub (S3 Export) Configuration
| Config Key | Description | Default |
|------------|-------------|---------|
| `pubsub.enable` | Enable S3 log export | `false` |
| `pubsub.retryInterval` | Pub/sub reconnect interval | `30s` |
| `pubsub.dataExporterKafka.subscriptionId` | Subscription ID | `data-exporter-kafka` |
| `pubsub.dataExporterKafka.logExportTopicName` | Pub/sub topic | `cdc-kafka-flow-export` |

### Authentication
- **OPHID mTLS**: Clients present certificates signed by `aws-pca-onprem` CA
- **Auth URL**: `http://identity-api.identity.svc.cluster.local/v2/session/verify`
- **Athena Claims**: Account ID and domain extracted from JWT context via `athena-authn-claims`

### Prometheus Metrics
| Metric | Type | Description |
|--------|------|-------------|
| `ti_data_exporter_kafka_onprem_sent_messages_total` | Counter | Total messages sent to on-prem hosts |
| `ti_data_exporter_kafka_onprem_sent_bytes_total` | Counter | Total bytes sent |
| `ti_data_exporter_kafka_onprem_fails_total` | Counter | Total transmission errors |
| `ti_data_exporter_kafka_active_connections_current` | Gauge | Currently active connections |

## Dependencies

### Go Dependencies
- `google.golang.org/grpc` — gRPC server framework
- `github.com/Shopify/sarama` — Kafka consumer groups (Sarama v2.5.0 protocol)
- `github.com/Infoblox-CTO/athena-authn-claims` — OPHID/account authentication
- `github.com/Infoblox-CTO/atlas.ophidauth.middleware` — mTLS middleware
- `github.com/aws/aws-sdk-go` — S3 file upload (log export)
- `github.com/infobloxopen/atlas-pubsub` — Pub/sub for S3 export events
- `github.com/prometheus/client_golang` — Prometheus metrics
- `github.com/infobloxopen/atlas-app-toolkit` — Health checks, server framework, cmode
- `github.com/golang/protobuf` — Protobuf serialization

### CDC Ecosystem
- **cdc.grpc-in**: On-prem client that connects to DEK
- **cdc.flow.api.service**: Manages flows that define which data types to export
- **cdc.kafka.flow.processor**: Writes events to Kafka topics consumed by DEK
- **soar-light**: Shares protobuf definitions and data stream protocol

## Build & Deploy

### Build
```bash
make default        # Build, test, Docker image
make build          # Build Go binary
make test           # Run unit tests
make image          # Build Docker image
```

### Endpoints
| Endpoint | Port | Description |
|----------|------|-------------|
| gRPC `DataReq` | 9090 | Server-streaming data export |
| gRPC `AckDataReceived` | 9090 | Acknowledgment (currently ignored) |
| `/metrics` | 9090 | Prometheus metrics |
| `/health` | 8081 | Health check |
| `/ready` | 8081 | Readiness probe |
| `/pprof` | 9090 | Heap profile dump |

### Helm Deployment
```bash
helm install data-exporter-kafka ./helm/data-exporter-kafka \
  --set replicas=3 \
  --set args.consumer.brokers="broker1:9092,broker2:9092" \
  --set host.grpcCsp.domain="myhost.example.com"
```

**Key Helm features:**
- **3 replicas** with pod anti-affinity for high availability
- **NGINX ingress** with sticky sessions (`$remote_dn` hash — binary remote addr + client DN)
- **mTLS pass-through**: `auth-tls-verify-client: optional`, `auth-tls-verify-depth: 2`
- **gRPC timeouts**: `grpc_read_timeout: 360d`, `grpc_send_timeout: 360d` (long-lived streams)
- **HPA**: Horizontal Pod Autoscaler support
- **PDB**: Pod Disruption Budget for rolling updates
- **Grafana dashboard**: Monitoring included
- Resources: 2Gi memory, 500m CPU per replica
