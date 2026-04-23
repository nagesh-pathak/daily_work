# CDC Syslog-Out (cdc.syslog-out)

## Overview
Syslog forwarding service for CDC data. Supports TCP, UDP, and TLS transport protocols with CEF (ArcSight), LEEF (QRadar), and JSON output formats. Dual-mode: Cloud (Dapr/Kafka) and On-Prem (file-based).

## Architecture

```
Cloud Mode:
  Dapr subscriber (port 8082) → Kafka consumer → Formatter (CEF/LEEF/JSON) → Syslog forwarder (TCP/UDP/TLS)

On-Prem Mode:
  Config file (inotify) → Directory monitor (/data/out/syslog/) → Worker pool → Persistent syslog connections
```

## Transport Protocols

| Protocol | Description | Delivery | Max Size | Port |
|----------|-------------|----------|----------|------|
| **TCP** | Persistent connection, newline-delimited, auto-reconnect | Reliable | Unlimited (stream) | 514 |
| **UDP** | Stateless datagrams, no delivery guarantee | Best-effort | 64 KB | 514 |
| **TLS** | x509 certificate validation, mTLS optional, SNI support, min TLS 1.2 | Reliable + Encrypted | Unlimited (stream) | 6514 |

## Output Formats

| Format | Target SIEM | Example |
|--------|------------|---------|
| **CEF** | ArcSight | `CEF:0\|Infoblox\|BloxOne\|1.0\|DNS\|query\|3\|src=... dst=...` |
| **LEEF** | IBM QRadar | `LEEF:2.0\|Infoblox\|BloxOne\|1.0\|DNS\|src=... dst=...` |
| **JSON** | Generic SIEM | Standard JSON objects |

## Cloud Mode
- Dapr PubSub subscriber (port 8082)
- Per-flow Kafka consumer groups
- Kafka topic: `{acctId}_{flowId}_syslog_{dataType}`
- Concurrent workers per flow

## On-Prem Mode
- Config: `/infoblox/etc/syslog-out.json`
- Input dirs: `/infoblox/data/out/syslog/{nios/dns, nios/rpz, bloxone/dns, bloxone/dhcp}`
- Persistent TCP/TLS connections reused across messages
- Files processed → moved to `done/` → cleaned by cdc.agent

## Connection Management
- Persistent TCP/TLS connections
- Auto-reconnect with exponential backoff
- 1 connection per destination per flow
- Idle timeout: 60s default
- TLS: cert/key pair, CA bundle, skip verification option

## Error Handling
- Exponential backoff on connection failure
- 3 consecutive failures → pause
- Auto-recovery with probe requests
- Memory buffer queue for failed messages

## Syslog Destinations

| Destination | Format | Transport | Default Port |
|-------------|--------|-----------|-------------|
| ArcSight | CEF | TCP / TLS | 514 / 6514 |
| QRadar | LEEF | TCP / TLS | 514 / 6514 |
| Generic SIEM | JSON | TCP / UDP / TLS | 514 / 6514 |
| Custom syslog server | Configurable | Configurable | Configurable |

## Data Types

| Data Type | Description |
|-----------|-------------|
| `TD_QUERY_RESP_LOG` | Threat Defense DNS query/response logs |
| `TD_THREAT_FEEDS_HITS_LOG` | Threat feed hit logs |
| `DDI_QUERY_RESP_LOG` | DDI DNS query/response logs |
| `DDI_DHCP_LEASE_LOG` | DDI DHCP lease logs |
| `AUDIT_LOG` | Audit trail logs |
| `SERVICE_LOG` | Service operational logs |
| `SOC_INSIGHTS` | SOC Insights v1 |
| `SOC_INSIGHTS_V2` | SOC Insights v2 |
| `ATLAS_NOTIFICATIONS` | Atlas notification events |

## Dependencies
- Dapr PubSub, Kafka (Cloud)
- Config Manager (On-Prem)
- cdc.common (health, crypt, datamonitor, logger)
- Flume Pipeline (On-Prem, produces CSV files)
- HashiCorp Vault (TLS cert decryption)

## Key Packages

| Package | Purpose |
|---------|---------|
| `cmd/` | Entry point |
| `pkg/syslog/` | Syslog protocol implementation |
| `pkg/formatter/` | CEF, LEEF, JSON formatters |
| `pkg/connection/` | TCP/UDP/TLS connection pool |
| `pkg/health/` | Health monitoring |
| `pkg/worker/` | Worker pool |
