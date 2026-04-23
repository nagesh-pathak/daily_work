# CDC HTTP-Out (`cdc.http-out`)

## Overview

HTTP destination service for **Splunk HEC** and **Microsoft Sentinel**. Operates in two modes:

| Mode | Trigger | Pipeline |
|------|---------|----------|
| **Cloud** | Dapr PubSub / Kafka consumer | Kafka topic → worker pool → HTTP POST |
| **On-Prem** | Config file + directory monitor | inotify → CSV ingest → worker pool → HTTP POST |

---

## Architecture

```
┌─────────────────────────────────────── Cloud Mode ───────────────────────────────────────┐
│                                                                                          │
│  Kafka Topic                    Dapr PubSub             Worker Pool        Destination   │
│  {acctId}_{flowId}_http_*  ──▶  :8082 subscriber  ──▶  N goroutines  ──▶  HTTP POST     │
│                                                                           ├─ Splunk HEC  │
│                                                                           └─ Sentinel    │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────── On-Prem Mode ─────────────────────────────────────┐
│                                                                                          │
│  Config File                 Directory Monitor          Worker Pool        Destination   │
│  http-out.json (inotify) ──▶ /infoblox/data/out/http ──▶ N goroutines ──▶ HTTP POST     │
│                               └─ watches for new CSV      ├─ Splunk HEC                 │
│                                                            └─ Sentinel                   │
└──────────────────────────────────────────────────────────────────────────────────────────┘

Health endpoint ──▶ :10001
```

---

## Cloud Mode

| Parameter | Value |
|-----------|-------|
| Dapr PubSub port | `8082` |
| Consumer group | Per-flow Kafka consumer groups |
| Kafka topic pattern | `{acctId}_{flowId}_http_{dataType}` |
| Concurrency | Worker pool of concurrent HTTP senders |

```
Kafka ──▶ Dapr PubSub (:8082) ──▶ Consumer Group (per flow) ──▶ Worker Pool ──▶ HTTP POST
```

---

## On-Prem Mode

| Parameter | Value |
|-----------|-------|
| Config path | `/infoblox/etc/http-out.json` |
| Input base dir | `/infoblox/data/out/http/` |
| Watch mechanism | `inotify` on input directories |
| Post-processing | Files moved to `done/`, cleaned by `cdc.agent` |

### Input Directory Structure

```
/infoblox/data/out/http/
├── nios/
│   ├── dns/          # NIOS DNS query logs
│   └── rpz/          # NIOS RPZ hit logs
├── bloxone/
│   ├── dns/          # BloxOne DNS query logs
│   └── dhcp/         # BloxOne DHCP logs
└── <type>/
    ├── *.csv          ← new files detected via inotify
    └── done/          ← processed files moved here
```

### On-Prem Pipeline

```
1. inotify detects config change  ──▶  reload http-out.json
2. inotify detects new CSV file   ──▶  enqueue to worker pool
3. Worker reads CSV rows           ──▶  batch into HTTP payloads
4. HTTP POST to destination        ──▶  move file to done/
5. cdc.agent periodically          ──▶  cleans done/ directory
```

---

## Splunk HEC Destination

| Parameter | Value |
|-----------|-------|
| Endpoint | `POST /services/collector/event` |
| Auth | `Authorization: Bearer {HEC token}` |
| Batch size | 100 events per request |
| Format | JSON event envelope |
| TLS | Configurable certificate validation |

### Sourcetype Mapping

| Data Type | Sourcetype |
|-----------|------------|
| DNS queries | `infoblox:cloud:dns` |
| RPZ hits | `infoblox:cloud:rpz` |

### Splunk HEC Payload

```json
{
  "event": {
    "qname": "example.com",
    "qtype": "A",
    "rcode": "NOERROR",
    "src_ip": "10.0.0.1",
    "timestamp": "2026-03-30T12:00:00Z"
  },
  "index": "infoblox_dns",
  "source": "cdc:http-out",
  "sourcetype": "infoblox:cloud:dns"
}
```

### Splunk Configuration

```json
{
  "destination": "splunk",
  "url": "https://splunk-hec.customer.com:8088",
  "token": "vault:secret/data/splunk-hec-token",
  "index": "infoblox_dns",
  "sourcetype": "infoblox:cloud:dns",
  "batch_size": 100,
  "ssl_verify": true
}
```

---

## MS Sentinel Destination

| Parameter | Value |
|-----------|-------|
| Auth | OAuth2 Azure AD `client_credentials` flow |
| Endpoint | DCR (Data Collection Rule) ingestion API |
| Format | ASIM (Azure Sentinel Information Model) |

### ASIM Field Mapping

| ASIM Field | Description | Example |
|------------|-------------|---------|
| `DnsQueryName` | Queried domain name | `example.com` |
| `SrcIpAddr` | Source IP address | `10.0.0.1` |
| `DnsResponseCode` | DNS response code | `NOERROR` |
| `EventTimestamp` | Event timestamp (ISO 8601) | `2026-03-30T12:00:00Z` |
| `EventType` | Type of event | `Query` |
| `EventResult` | Result of the event | `Success` |

### Sentinel OAuth2 Flow

```
1. POST https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token
   grant_type=client_credentials
   client_id={client_id}
   client_secret={client_secret}  (Vault encrypted)
   scope=https://monitor.azure.com/.default

2. POST {dcr_endpoint}/dataCollectionRules/{dcr_rule_id}/streams/{stream_name}?api-version=2023-01-01
   Authorization: Bearer {access_token}
   Content-Type: application/json
   Body: [ { "DnsQueryName": "...", "SrcIpAddr": "...", ... } ]
```

### Sentinel Configuration

```json
{
  "destination": "sentinel",
  "tenant_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "client_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "client_secret": "vault:secret/data/sentinel-client-secret",
  "dcr_endpoint": "https://dcr-ingest.monitor.azure.com",
  "dcr_rule_id": "dcr-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "stream_name": "Custom-InfobloxDNS_CL"
}
```

---

## Error Handling

### Retry Strategy

| Parameter | Value |
|-----------|-------|
| Algorithm | Exponential backoff |
| Base delay | `500ms` |
| Formula | `500ms × 2^n` |
| Max retries | 5 |
| Max delay | `500ms × 2^5 = 16s` |

```
Attempt 1:   500ms
Attempt 2:  1000ms
Attempt 3:  2000ms
Attempt 4:  4000ms
Attempt 5:  8000ms
  (give up after 5 failures)
```

### Health State Machine

```
                 success
    ┌───────────────────────────────┐
    ▼                               │
┌────────┐   3 consecutive    ┌──────────┐   probe success   ┌─────────┐
│healthy │──── failures ─────▶│unhealthy │──────────────────▶│ paused  │
└────────┘                    └──────────┘                   └─────────┘
    ▲                               │                             │
    │         recovery probe        │     periodic probe          │
    └───────────────────────────────┘◀────────────────────────────┘
```

| State | Behavior |
|-------|----------|
| `healthy` | Normal sending; reset failure counter on success |
| `unhealthy` | 3 consecutive failures → transition to paused |
| `paused` | Stop sending; run periodic probe requests to check destination availability |

### Dead Letter Handling

| Scenario | Action |
|----------|--------|
| Max retries exhausted | Event logged to dead-letter log |
| Kafka offset | Committed (no reprocessing) |
| File-based (on-prem) | File moved to `done/` with error annotation |

---

## Configuration Reference

### Splunk HEC Config

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `url` | `string` | Yes | Splunk HEC endpoint URL |
| `token` | `string` | Yes | HEC token (Vault-encrypted) |
| `index` | `string` | Yes | Target Splunk index |
| `sourcetype` | `string` | Yes | Splunk sourcetype |
| `batch_size` | `int` | No | Events per batch (default: 100) |
| `ssl_verify` | `bool` | No | Validate TLS certificates (default: true) |

### Sentinel Config

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `tenant_id` | `string` | Yes | Azure AD tenant ID |
| `client_id` | `string` | Yes | Azure AD app client ID |
| `client_secret` | `string` | Yes | Client secret (Vault-encrypted) |
| `dcr_endpoint` | `string` | Yes | DCR ingestion API endpoint |
| `dcr_rule_id` | `string` | Yes | Data Collection Rule ID |
| `stream_name` | `string` | Yes | DCR stream name |

---

## Dependencies

| Dependency | Mode | Purpose |
|------------|------|---------|
| Dapr PubSub | Cloud | Kafka topic subscription on port 8082 |
| Kafka | Cloud | Event streaming / consumer groups |
| Config Manager | On-Prem | Manages `http-out.json` lifecycle |
| `cdc.common` | Both | Shared libraries: health, crypt, datamonitor, logger |
| HashiCorp Vault | Both | Credential decryption (HEC tokens, client secrets) |
| `cdc.agent` | On-Prem | Cleans processed files from `done/` directories |

---

## Key Packages

| Package | Path | Description |
|---------|------|-------------|
| Entry point | `cmd/` | Main binary, mode selection (cloud/on-prem) |
| HTTP sender | `pkg/http/` | Generic HTTP POST client with retry logic |
| Splunk HEC | `pkg/splunk/` | Splunk HEC protocol, batching, event envelope |
| Sentinel DCR | `pkg/sentinel/` | Azure OAuth2 + DCR ingestion API client |
| Config loader | `pkg/config/` | JSON config parsing, inotify-based reload |
| Health monitor | `pkg/health/` | Health states, probe, endpoint on `:10001` |
| Worker pool | `pkg/worker/` | Concurrent goroutine pool for HTTP sending |

---

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| `8082` | HTTP | Dapr PubSub subscriber (cloud mode) |
| `10001` | HTTP | Health check endpoint |
