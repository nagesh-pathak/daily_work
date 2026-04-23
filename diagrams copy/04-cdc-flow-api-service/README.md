# CDC Flow API Service (`cdc.flow.api.service`)

## Overview

Generic gRPC/REST API for the full CDC flow lifecycle — orchestrating sources, destinations, ETL filters, hosts, and container configs across cloud and on-prem deployments. This service is the central control plane for creating, managing, and deploying CDC data flows end-to-end.

---

## Architecture

```
                  ┌─────────────────────────────────────────────────┐
                  │          CDC Flow API Service                   │
                  │                                                 │
  HTTP/REST ─────►│  :8080  REST Gateway (protoc-gen-gateway)       │
                  │         ↓                                       │
  gRPC ──────────►│  :9090  gRPC Server (Atlas App Toolkit)         │
                  │         ↓                                       │
  Health ────────►│  :8086  Health/Ready probes                     │
                  │                                                 │
                  │  Framework: Atlas App Toolkit                   │
                  │  - GORM (PostgreSQL ORM)                        │
                  │  - Validation middleware                        │
                  │  - Request ID propagation                       │
                  │  - JWT authentication interceptor               │
                  └──────┬──────────┬──────────┬───────────────────┘
                         │          │          │
                    PostgreSQL    Kafka     Dapr PubSub
```

| Port  | Protocol | Purpose                              |
|-------|----------|--------------------------------------|
| 8080  | HTTP     | REST Gateway (protoc-gen-gateway)     |
| 9090  | gRPC     | Primary gRPC server                  |
| 8086  | HTTP     | Health and readiness probes           |

---

## API Services

### 1. FlowApiV2 — Flow Lifecycle

CRUD operations for CDC flows with state management.

| Operation | Method       | Description                        |
|-----------|--------------|------------------------------------|
| Create    | `CreateFlow` | Create a new flow in Draft state   |
| Read      | `ReadFlow`   | Get flow by ID                     |
| Update    | `UpdateFlow` | Modify flow configuration          |
| Delete    | `DeleteFlow` | Soft-delete a flow                 |
| List      | `ListFlows`  | List flows with filtering/paging   |

**Flow States:**

```
Draft ──► Active ──► Paused ──► Deleted
  │                    │
  └────────────────────┘
       (reactivate)
```

### 2. SourceApi — Data Sources

CRUD for data sources bound to a flow.

| Source Type | Description                          |
|-------------|--------------------------------------|
| NIOS        | On-prem NIOS appliance               |
| BloxOne     | BloxOne cloud platform               |
| Schedule    | Scheduled/batch data ingestion       |
| Ingress     | Generic ingress endpoint             |

### 3. DestinationApi — Data Destinations

CRUD for output destinations bound to a flow.

| Destination Type | Description                        |
|------------------|------------------------------------|
| Splunk           | Splunk Enterprise (HEC)            |
| SplunkCloud      | Splunk Cloud (HEC)                 |
| Syslog           | Syslog over TCP/UDP/TLS            |
| HTTP             | Generic HTTP/HTTPS endpoint        |
| Application      | SOAR/Reporting applications        |
| Reporting        | Internal reporting pipeline        |
| BloxOne          | BloxOne cloud destination          |
| Ingress          | Generic ingress destination        |

### 4. EtlFilterApi — ETL Filter Rules

CRUD for ETL filter rules applied per flow.

| Filter Type    | Description                            |
|----------------|----------------------------------------|
| IP_NETWORK     | Filter by IP network/CIDR              |
| FQDN           | Filter by fully qualified domain name  |
| HOSTNAME       | Filter by hostname pattern             |
| REGEX          | Filter by regular expression           |
| THREAT_CLASS   | Filter by threat classification        |
| OPHID          | Filter by on-prem host ID             |
| RECORD_TYPE    | Filter by DNS record type              |
| LOCAL_ZONES    | Filter by local DNS zones              |

### 5. HostApi — CDC Host Management

Register, list, and delete CDC hosts (on-prem appliances).

### 6. ServiceApi — Container Service Management

Manage container services deployed per host.

### 7. ConfigApi — Versioned Configuration

Versioned configuration management per container instance.

### 8. ApplicationApi — Application Lifecycle

SOAR and Reporting application lifecycle management.

---

## Database Schema (PostgreSQL)

### Entity Relationship

```
flows ──────┬──── sources
            ├──── destinations ──── flow_destinations
            ├──── etls
            └──── flow_cdc_services ──── cdc_services ──── cdc_hosts
```

### Table Definitions

#### `flows`

| Column       | Type        | Description                                |
|--------------|-------------|--------------------------------------------|
| id           | UUID (PK)   | Unique flow identifier                     |
| account_id   | STRING      | Tenant/account identifier                  |
| name         | STRING      | Human-readable flow name                   |
| description  | TEXT        | Flow description                           |
| source_type  | ENUM        | Source type (NIOS, BloxOne, etc.)           |
| state        | ENUM        | Flow state (Draft, Active, Paused, Deleted)|
| data_types   | STRING[]    | Array of supported data types              |
| schedule     | STRING      | Cron schedule expression (if applicable)   |
| tags         | JSONB       | User-defined tags                          |
| metadata     | JSONB       | Additional flow metadata                   |
| created_at   | TIMESTAMP   | Creation timestamp                         |
| updated_at   | TIMESTAMP   | Last update timestamp                      |

#### `sources`

| Column       | Type        | Description                                |
|--------------|-------------|--------------------------------------------|
| id           | UUID (PK)   | Unique source identifier                   |
| flow_id      | UUID (FK)   | Associated flow                            |
| source_type  | ENUM        | Source type                                |
| config       | JSONB       | Source-specific configuration              |
| account_id   | STRING      | Tenant/account identifier                  |
| ophid        | STRING      | On-prem host ID (if applicable)            |

#### `destinations`

| Column          | Type        | Description                             |
|-----------------|-------------|-----------------------------------------|
| id              | UUID (PK)   | Unique destination identifier           |
| flow_id         | UUID (FK)   | Associated flow                         |
| dest_type       | ENUM        | Destination type                        |
| config          | JSONB       | Destination-specific configuration      |
| credentials_id  | STRING      | Vault credential reference              |
| account_id      | STRING      | Tenant/account identifier               |

#### `cdc_hosts`

| Column       | Type        | Description                                |
|--------------|-------------|--------------------------------------------|
| id           | UUID (PK)   | Unique host identifier                     |
| ophid        | STRING      | On-prem host ID                            |
| host_type    | ENUM        | Host type classification                   |
| account_id   | STRING      | Tenant/account identifier                  |
| ha_state     | ENUM        | High-availability state                    |

#### `etls`

| Column       | Type        | Description                                |
|--------------|-------------|--------------------------------------------|
| id           | UUID (PK)   | Unique ETL filter identifier               |
| flow_id      | UUID (FK)   | Associated flow                            |
| filter_type  | ENUM        | Filter type (IP_NETWORK, FQDN, etc.)       |
| filter_data  | JSONB       | Filter-specific rule data                  |

#### `flow_destinations`

| Column         | Type        | Description                              |
|----------------|-------------|------------------------------------------|
| flow_id        | UUID (FK)   | Associated flow                          |
| destination_id | UUID (FK)   | Associated destination                   |
| container_name | STRING      | Container name for this flow-destination |

#### `flow_cdc_services`

| Column      | Type        | Description                                 |
|-------------|-------------|---------------------------------------------|
| flow_id     | UUID (FK)   | Associated flow                             |
| service_id  | UUID (FK)   | Associated CDC service                      |

---

## Flow Lifecycle

### End-to-End Flow Creation

```
User Request
    │
    ▼
1. Create Flow ──► Validate request (schema, account, permissions)
    │
    ▼
2. Store in PostgreSQL ──► flows, sources, destinations, etls tables
    │
    ▼
3. Create Kafka Topics ──► {accountId}_flowID{flowId}_{dataSourceName}
    │
    ▼
4. Publish Dapr Event ──► topic: cdc-flow-{env}
    │                      action: FLOW_CREATE
    ▼
5. CDC Agent Receives Event ──► Downloads flow config via gRPC
    │
    ▼
6. Agent Creates K8s ConfigMaps ──► Per-container configuration
    │
    ▼
7. Agent Reconciles StatefulSets ──► grpc-in, splunk-out, syslog-out, etc.
    │
    ▼
8. Containers Start ──► Data pipeline is live
```

### State Transitions

| From    | To      | Trigger            | Side Effects                          |
|---------|---------|--------------------|---------------------------------------|
| —       | Draft   | CreateFlow         | DB record created                     |
| Draft   | Active  | ActivateFlow       | Kafka topics created, Dapr event sent |
| Active  | Paused  | PauseFlow          | Dapr event sent, containers scaled down|
| Paused  | Active  | ReactivateFlow     | Dapr event sent, containers scaled up |
| Any     | Deleted | DeleteFlow         | Kafka topics deleted, Dapr event sent |

---

## Kafka Integration

Uses the Sarama admin client for Kafka topic management.

### Topic Naming Convention

```
{accountId}_flowID{flowId}_{dataSourceName}
```

**Examples:**

```
acct_12345_flowID_abc-def-1234_TD_QUERY_RESP_LOG
acct_12345_flowID_abc-def-1234_DDI_DHCP_LEASE_LOG
acct_67890_flowID_xyz-uvw-5678_AUDIT_LOG
```

### Topic Operations

| Operation | Trigger      | Description                                    |
|-----------|-------------|------------------------------------------------|
| Create    | Flow Active  | Creates topics for each data type in the flow  |
| Delete    | Flow Delete  | Removes all topics associated with the flow    |

### Configuration

| Parameter          | Description                          |
|--------------------|--------------------------------------|
| Partitions         | Configurable per deployment          |
| Replication Factor | Configurable per deployment          |
| Broker List        | Kafka cluster bootstrap servers      |

---

## Dapr PubSub

### Event Publishing

Publishes flow lifecycle events to the Dapr PubSub component.

**Topic:** `cdc-flow-{env}`

| Event          | Description                              |
|----------------|------------------------------------------|
| FLOW_CREATE    | New flow activated                       |
| FLOW_UPDATE    | Existing flow configuration changed      |
| FLOW_DELETE    | Flow deleted                             |

### Event Payload

```json
{
  "flow_id": "abc-def-1234",
  "ophid": "on-prem-host-001",
  "account_id": "acct_12345",
  "action": "FLOW_CREATE",
  "container_type": "splunk-out"
}
```

### Event Flow

```
Flow API Service
    │
    ▼ (Dapr Sidecar)
Dapr PubSub (Redis/Kafka)
    │
    ▼ (Subscription)
CDC Agent ──► Reconcile K8s resources
```

---

## Kubernetes Integration

### Resources Managed

| Resource     | Purpose                                        |
|--------------|------------------------------------------------|
| StatefulSet  | Per-flow container workloads (grpc-in, splunk-out, etc.) |
| ConfigMap    | Container configuration per flow               |
| Service      | Internal networking for containers             |

### Service Account

```
Service Account: cdc-data-flow-sa
RBAC:           Defined in cdc.data.flow Helm chart
Permissions:    Create/Update/Delete StatefulSets, ConfigMaps, Services
```

### Container Types Deployed

| Container    | Purpose                                |
|--------------|----------------------------------------|
| grpc-in      | Ingest data via gRPC from NIOS/BloxOne |
| splunk-out   | Forward data to Splunk HEC             |
| syslog-out   | Forward data to Syslog endpoints       |
| http-out     | Forward data to HTTP endpoints         |
| etl          | Apply ETL filter transformations       |

---

## External Dependencies

| Dependency                  | Purpose                                    |
|-----------------------------|--------------------------------------------|
| `atlas.status.service`      | Flow and host status aggregation           |
| `csp.host-app.service`      | Host/appliance management and registration |
| `atlas.feature.flag`        | Feature toggle evaluation                  |
| Tide API                    | Threat intelligence data integration       |
| HashiCorp Vault             | Credential encryption/decryption           |
| CSP Identity Service        | JWT authentication and token validation    |
| Kafka Cluster               | Message transport for data flows           |
| Dapr Sidecar                | PubSub event bus for flow lifecycle events |
| Kubernetes API              | StatefulSet and ConfigMap management       |

---

## Data Types Supported

| Data Type                  | Description                             |
|----------------------------|-----------------------------------------|
| TD_QUERY_RESP_LOG          | Threat Defense DNS query response logs   |
| TD_THREAT_FEEDS_HITS_LOG   | Threat Defense threat feed hit logs      |
| DDI_QUERY_RESP_LOG         | DDI DNS query response logs             |
| DDI_DHCP_LEASE_LOG         | DDI DHCP lease event logs               |
| AUDIT_LOG                  | Platform audit trail logs               |
| SERVICE_LOG                | Internal service operational logs       |
| ATLAS_NOTIFICATIONS        | Atlas platform notification events      |
| SOC_INSIGHTS               | SOC Insights security analytics (v1)    |
| SOC_INSIGHTS_V2            | SOC Insights security analytics (v2)    |

---

## Key Packages

```
cdc.flow.api.service/
├── server/      gRPC server setup, interceptors, middleware
├── service/     Business logic for each API service
├── repo/        PostgreSQL repository layer (GORM)
├── kafka/       Sarama admin client for topic management
├── dapr/        PubSub event publishing
├── k8s/         Kubernetes client for StatefulSet/ConfigMap
├── proto/       Protobuf definitions and generated code
└── cmd/         Application entrypoint
```

| Package    | Responsibility                                          |
|------------|---------------------------------------------------------|
| `server/`  | gRPC server bootstrap, interceptor chain, REST gateway  |
| `service/` | Business logic for FlowApi, SourceApi, DestinationApi, EtlFilterApi, HostApi, ServiceApi, ConfigApi, ApplicationApi |
| `repo/`    | PostgreSQL repository with GORM — queries, migrations, transactions |
| `kafka/`   | Sarama admin client — topic create/delete, partition management |
| `dapr/`    | Dapr PubSub client — publish flow lifecycle events      |
| `k8s/`     | Kubernetes client-go — StatefulSet, ConfigMap, Service CRUD |

---

## Configuration

Key environment variables and config options:

| Variable                  | Description                               |
|---------------------------|-------------------------------------------|
| `GRPC_PORT`               | gRPC server port (default: 9090)          |
| `HTTP_PORT`               | REST gateway port (default: 8080)         |
| `HEALTH_PORT`             | Health check port (default: 8086)         |
| `DB_HOST`                 | PostgreSQL host                           |
| `DB_PORT`                 | PostgreSQL port                           |
| `DB_NAME`                 | PostgreSQL database name                  |
| `KAFKA_BROKERS`           | Kafka bootstrap servers                   |
| `KAFKA_PARTITIONS`        | Default topic partitions                  |
| `KAFKA_REPLICATION_FACTOR`| Default topic replication factor          |
| `DAPR_PUBSUB_NAME`       | Dapr PubSub component name                |
| `DAPR_TOPIC`              | Dapr topic for flow events                |
| `VAULT_ADDR`              | HashiCorp Vault address                   |
| `ENV`                     | Deployment environment (dev, staging, prod)|

---

## Summary

The CDC Flow API Service is the orchestration hub for the entire CDC data pipeline. It provides a unified API surface for managing flows from creation through deployment, coordinating across PostgreSQL (persistence), Kafka (data transport), Dapr (event notifications), and Kubernetes (workload deployment) to deliver a fully automated data flow lifecycle.
