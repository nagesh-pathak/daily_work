# CDC (Cloud Data Connector) — End-to-End Architecture Overview

## What is CDC?

**Cloud Data Connector (CDC)** is Infoblox's enterprise data pipeline platform that collects DNS, DHCP, RPZ, and IPAM data from both **on-premises NIOS appliances** and **BloxOne Cloud services**, transforms it into multiple output formats, and delivers it to external security and analytics platforms (Splunk, Microsoft Sentinel, Syslog/SIEM, HTTP endpoints, SOAR tools).

CDC operates in **two deployment modes**:
- **On-Premises (NIOS)**: File-based pipeline using Apache Flume for transformation and routing
- **Cloud (BloxOne)**: Kafka-based streaming pipeline with Dapr-orchestrated microservices on Kubernetes

---

## Architecture Layers

### 1. Data Sources
| Source | Data Types | Protocol |
|--------|-----------|----------|
| **NIOS Grid** | DNS query/response logs, RPZ policy events, IPAM metadata | SSH/SCP, Syslog/TLS, WAPI REST |
| **BloxOne Cloud** | Threat Defense DNS, DDI DHCP leases, Audit logs | Kafka topics |
| **SOC Analytics** | SOC Insights v1/v2, Atlas Notifications | Kafka topics |

### 2. Ingestion Layer (On-Premises)
| Component | Function | Input | Output |
|-----------|----------|-------|--------|
| **cdc.dns-in** | DNS capture ingestion | SSH/SCP .gz files from NIOS | Flume staging dir |
| **cdc.rpz-in** | RPZ event ingestion | Syslog/TLS (port 6514) from NIOS | Flume staging dir |
| **cdc.wapi-in** | IPAM metadata ingestion | WAPI REST API polling | Avro files → Flume |
| **cdc.flume** | Transform & multi-route | Staging directories | CSV/Parquet/CEF/LEEF/JSON files |
| **cdc.grpc-out** | Cloud upload | Parquet files | gRPC stream → ti-proxy → Kafka |
| **cdc.rest-out** | Cloud REST upload | Parquet files | HTTP POST → Cloud API |
| **cdc.agent** | Disk/health management | File system monitoring | Cleanup + metrics |

### 3. Cloud Processing Layer
| Component | Function | Input | Output |
|-----------|----------|-------|--------|
| **cdc.kafka.flow.processor** | Flow routing & filtering | Source Kafka topics | Flow-specific Kafka topics |
| **data.exporter.kafka** | On-prem delivery | Kafka flow topics | gRPC stream to on-prem hosts |
| **cdc.grpc-in (cloud)** | Format transformation | Kafka (Parquet data) | Kafka (CSV/CEF/LEEF/JSON/ASIM) |
| **cdc.crds** | CRD registry | K8s API | CloudDataSource objects |
| **cdc.data.flow** | K8s RBAC & Helm | Helm values | ServiceAccount, Roles, Dashboard |

### 4. API & Management Layer
| Component | Function |
|-----------|----------|
| **cdc.flow.api.service** | Primary REST/gRPC API for flow lifecycle management (CRUD) |
| **cdc.api** | Container config versioning, ETL filters, Flume orchestration |
| **cdc.infraservice** | Flume config template rendering, PubSub notification |
| **atlas.config.manager** | Config delivery to on-prem hosts via PubSub |
| **atlas.status.service** | Flow/host/service health status tracking |
| **cdc.onboarding** | Customer setup guides, reporting tools |

### 5. Destination Outputs
| Component | Destination | Protocol | Formats |
|-----------|------------|----------|---------|
| **cdc.syslog-out** | Syslog servers | TCP/UDP/TLS | CEF, LEEF, JSON |
| **cdc.http-out** | Splunk HEC, MS Sentinel | HTTPS | ASIM, CIM, JSON |
| **cdc.splunk-out** | Splunk Enterprise/Cloud | Splunk UF (TCP/TLS) | CSV |
| **cdc.siem-out** | ArcSight, QRadar | Splunk UF (TLS) | CEF, LEEF |
| **cdc.reporting-out** | Infoblox Reporting | Splunk UF | CSV |
| **soar-light** | Custom SOAR platforms | gRPC/Kafka → Python scripts | Configurable |

### 6. Shared Infrastructure
| Component | Function |
|-----------|----------|
| **cdc.common** | Shared library: health checks, AES-256 crypto, logging, metrics, config, disk cleanup |
| **cdc.appbase** | Base Docker image (Alpine Linux, OpenJDK 8, Python) |
| **cdc.splunkforwarderbase** | Splunk UF 9.1.0 base image with config templating |
| **cdc.etl** | Standalone Parquet → CSV transformation library |
| **bloxone.automation.scripts** | SOAR script CI/CD pipeline for 20+ integrations |

---

## Kafka Topic Naming Conventions

| Pattern | Usage | Example |
|---------|-------|---------|
| `{accountId}_flowID{flowId}_{dataType}` | Flow processor input topics | `2001048_flowID54379_TD_QUERY_RESP_LOG` |
| `{accountId}_{flowId}_{destination}_{dataType}` | grpc-in output topics | `2001048_54379_SYSLOG_OUTPUT_TD_QUERY_RESP_LOG` |
| `{accountId}_{flowId}_SYSLOG_{dataType}` | Syslog-out consumption | `acc123_42_SYSLOG_dns` |
| `cm-{container_name}-{env}` | Config manager delivery | `cm-dns_in-prod` |
| `cdc-flow-{env}` | Flow lifecycle events | `cdc-flow-dev` |

---

## Supported Data Types

| Data Type | Source | Description |
|-----------|--------|-------------|
| `TD_QUERY_RESP_LOG` | BloxOne TD | Threat Defense DNS query/response |
| `TD_THREAT_FEEDS_HITS_LOG` | BloxOne TD | RPZ/Threat feed matches |
| `DDI_QUERY_RESP_LOG` | BloxOne DDI | DDI DNS query/response |
| `DDI_DHCP_LEASE_LOG` | BloxOne DDI | DHCP lease events |
| `AUDIT_LOG` | BloxOne | System audit events |
| `SERVICE_LOG` | BloxOne | Service operational logs |
| `ATLAS_NOTIFICATIONS` | Atlas | System notifications |
| `SOC_INSIGHTS` | SOC | Security analytics v1 |
| `SOC_INSIGHTS_V2` | SOC | Security analytics v2 |

---

## Diagram Index

| # | Component | Description |
|---|-----------|-------------|
| 00 | [CDC Overview](../00-cdc-overview/) | End-to-end architecture |
| 01 | [cdc.grpc-in](../01-cdc-grpc-in/) | Cloud data ingestion & transformation |
| 02 | [cdc.grpc-out](../02-cdc-grpc-out/) | On-prem to cloud file upload |
| 03 | [cdc.api](../03-cdc-api/) | Container config management |
| 04 | [cdc.flow.api.service](../04-cdc-flow-api-service/) | Flow lifecycle API |
| 05 | [cdc.agent](../05-cdc-agent/) | On-prem disk & health management |
| 06 | [cdc.etl](../06-cdc-etl/) | Parquet → CSV transformation library |
| 07 | [cdc.http-out](../07-cdc-http-out/) | HTTP destination (Splunk HEC, Sentinel) |
| 08 | [cdc.syslog-out](../08-cdc-syslog-out/) | Syslog destination (TCP/UDP/TLS) |
| 09 | [cdc.splunk-out](../09-cdc-splunk-out/) | Splunk UF destination |
| 10 | [cdc.siem-out](../10-cdc-siem-out/) | SIEM destination (CEF/LEEF) |
| 11 | [cdc.rest-out](../11-cdc-rest-out/) | REST egress to cloud |
| 12 | [cdc.dns-in](../12-cdc-dns-in/) | DNS capture ingestion from NIOS |
| 13 | [cdc.rpz-in](../13-cdc-rpz-in/) | RPZ syslog ingestion from NIOS |
| 14 | [cdc.wapi-in](../14-cdc-wapi-in/) | IPAM metadata ingestion via WAPI |
| 15 | [cdc.flume](../15-cdc-flume/) | Apache Flume transform & routing |
| 16 | [cdc.kafka.flow.processor](../16-cdc-kafka-flow-processor/) | Kafka flow routing & filtering |
| 17 | [cdc.data.flow](../17-cdc-data-flow/) | K8s Helm chart infrastructure |
| 18 | [cdc.infraservice](../18-cdc-infraservice/) | Flume config management |
| 19 | [cdc.common](../19-cdc-common/) | Shared libraries |
| 20 | [cdc.appbase](../20-cdc-appbase/) | Base Docker image |
| 21 | [soar-light](../21-soar-light/) | SOAR automation framework |
| 22 | [data.exporter.kafka](../22-data-exporter-kafka/) | Kafka → on-prem delivery |
| 23 | [cdc.crds](../23-cdc-crds/) | K8s CRD definitions |
| 24 | [cdc.reporting-out](../24-cdc-reporting-out/) | Reporting destination |
| 25 | [cdc.splunkforwarderbase](../25-cdc-splunkforwarderbase/) | Splunk UF base image |
| 26 | [cdc.onboarding](../26-cdc-onboarding/) | Customer onboarding tools |
