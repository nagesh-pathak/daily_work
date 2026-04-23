# cdc.grpc-in — Cloud Data Ingestion & Transformation Service

## Purpose
**cdc.grpc-in** is the primary data transformation bridge in the CDC ecosystem. It ingests log events from cloud Kafka topics (populated by `data-exporter-kafka` or `cdc.kafka.flow.processor`) and on-premises gRPC streams, transforms Parquet-encoded data into multiple output formats (CSV, CEF, LEEF, JSON, ASIM, Splunk CIM), and routes the transformed data to downstream destination services.

## Deployment Modes

### Cloud Mode (`cmd/cloud/main.go`)
- **Config Source**: Dapr PubSub events (FlowConfig, DestinationConfig)
- **Data Input**: Kafka topics (`{accountID}_flowID{flowID}_{dataType}`)
- **Data Output**: Kafka topics (`{accountID}_{flowID}_{destination}_{dataType}`)
- **Scaling**: Kubernetes pods with per-flow consumer groups

### On-Premises Mode (`cmd/onprem/main.go`)
- **Config Source**: JSON file at `/opt/grpc_in/conf/grpc_in.json` (hot-reloadable)
- **Data Input**: gRPC streaming from `data-exporter-kafka`
- **Data Output**: File system (`/infoblox/data/out/{dest}/`) or Soar-Light gRPC server
- **Scaling**: Single container per on-prem host

## Data Flow

### Cloud Pipeline
```
Dapr PubSub → FlowEvents/DestinationEvents
    ↓
Cloud Config Manager (thread-safe singleton)
    ↓
Kafka Consumer Manager → creates per-flow readers
    ↓
Kafka Input Topics: {accountID}_flowID{flowID}_{dataType}
    ↓
Worker Pool (parallel goroutines)
    ↓
Parser System (Parquet → target format)
    ↓
Kafka Producer (shared singleton, LeastBytes balancing)
    ↓
Kafka Output Topics: {accountID}_{flowID}_{dest}_{dataType}
    ↓
Downstream: cdc.syslog-out, cdc.http-out, soar-light
```

### On-Premises Pipeline
```
Config File (/opt/grpc_in/conf/grpc_in.json)
    ↓
gRPC Client → data-exporter-kafka (Subscribe with flow IDs)
    ↓
Data Cache (in-memory, thread-safe)
    ↓
Parser System (same parsers as cloud)
    ↓
File Output: /infoblox/data/out/{siem,splunk,http,reporting}/
  OR
Soar-Light gRPC Server (port 9195)
```

## Supported Data Types

| Data Type | Source | Description |
|-----------|--------|-------------|
| `TD_QUERY_RESP_LOG` | BloxOne TD | Threat Defense DNS query/response |
| `TD_THREAT_FEEDS_HITS_LOG` | BloxOne TD | Threat feed RPZ hits |
| `DDI_QUERY_RESP_LOG` | BloxOne DDI | DDI DNS query/response |
| `DDI_DHCP_LEASE_LOG` | BloxOne DDI | DHCP leases (protobuf) |
| `AUDIT_LOG` | BloxOne | Audit events |
| `SERVICE_LOG` | BloxOne | Service logs |
| `ATLAS_NOTIFICATIONS` | Atlas | System notifications |
| `SOC_INSIGHTS` | SOC | Security analytics v1 |
| `SOC_INSIGHTS_V2` | SOC | Security analytics v2 |

## Output Formats

| Format | Target | Description |
|--------|--------|-------------|
| **CSV** | Splunk/Reporting | Tab or comma delimited |
| **CEF** | ArcSight/SIEM | `CEF:0\|Infoblox\|...` pipe-delimited |
| **LEEF** | QRadar/SIEM | IBM Log Event Extended Format |
| **JSON** | HTTP/REST | Structured JSON objects |
| **ASIM** | MS Sentinel | Azure Sentinel Information Model |
| **Splunk CIM** | Splunk | Common Information Model |

## Key Packages

| Package | Responsibility |
|---------|---------------|
| `cloudworker` | Worker goroutine processing Kafka messages |
| `cloudconfig` | Thread-safe flow config storage (singleton) |
| `cloudschema` | FlowConfig, DestinationConfig event structures |
| `dapr/subscriber` | Dapr gRPC service for config events |
| `kafka/consumer` | Per-flow Kafka readers with topic validation |
| `kafka/producer` | Shared Kafka producer (singleton) |
| `kafka/flowtopic` | Topic naming: `{acctId}_flowID{fId}_{type}` |
| `parser` | Core: Parquet → CSV/CEF/LEEF/JSON/ASIM/Splunk |
| `client` | gRPC client for on-prem data-exporter-kafka |
| `dsclient` | Data stream gRPC client (newer protocol) |
| `cache` | In-memory data buffer with cleanup |
| `soarlightserver` | gRPC server for Soar-Light streaming |
| `metrics` | Prometheus metrics (received/processed counts) |

## Transformation Details

### DNS Log Processing
1. Parquet deserialization → `DnsLog` structs (via `xitongsys/parquet-go`)
2. Field extraction: opcode, timestamp, qname, qtype, qclass, source, protocol, qip, rip, rcode, delay
3. DNS flags: 16 boolean fields (qqr, qaa, qtc, qrd, qra, qad, qcd, qdo + response equivalents)
4. Resource records: 6 arrays (qrr1-3, rrr1-3) each with {name, ttl, type, class, data}
5. Format-specific serialization

### DHCP Lease Processing
1. Protobuf/Avro deserialization
2. Field enrichment: space, subnet, range, scope
3. MAC address formatting, IP range validation
4. Format conversion to target output

## Configuration

### Cloud (via Dapr Events)
```json
{
  "ID": 1234, "AccountID": "acct_123",
  "SourceDataTypes": ["TD_QUERY_RESP_LOG", "DDI_DHCP_LEASE_LOG"],
  "Destinations": [{"ID": 1, "Type": "SYSLOG", "OutputDataFormat": "cef"}]
}
```

### On-Premises (grpc_in.json)
```json
{
  "file_config": {
    "flows": [{"id": 404, "data_types": [{"type": "DDI_DHCP_LEASE_LOG", "input_folder": "ddi/dhcp"}],
      "destination": "siem_out", "out_format": "cef"}],
    "account_id": "account_123"
  }
}
```

### Environment Variables
| Variable | Purpose |
|----------|---------|
| `NS_OPH_ID` | On-prem host identifier |
| `KAFKA_BROKERS` | Comma-separated Kafka brokers |
| `DAPR_SUBSCRIBER_ADDRESS` | Dapr gRPC bind address |
| `LOGGING_LEVEL` | Log verbosity (default: info) |
| `SERVICE_ID` | Service identifier for metrics |

## Dependencies
- **data-exporter-kafka**: gRPC source (on-prem mode)
- **Kafka Brokers**: Input/output topic storage
- **Dapr PubSub**: Config delivery (cloud mode)
- **Soar-Light**: Application destination via gRPC
- **xitongsys/parquet-go**: Parquet deserialization
- **segmentio/kafka-go**: Kafka client library

## Health & Monitoring
- **Prometheus**: Port 9152 (metrics server)
- **Health/Ready**: Port 8081 (internal HTTP)
- **Profiling**: Optional pprof on dedicated port
