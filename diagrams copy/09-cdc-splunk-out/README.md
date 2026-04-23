# CDC Splunk-Out (`cdc.splunk-out`)

## Overview

Health check wrapper around `cdc.splunkforwarderbase`. **On-prem only — no Kafka.** Monitors Splunk Universal Forwarder health at port 8089 via TLS mutual authentication. The actual data forwarding is done by the Splunk UF from the base image.

---

## Architecture

```
Flume Pipeline
    │
    ▼
writes CSV to /data/out/splunk/
    │
    ▼
Splunk UF (from splunkforwarderbase)
monitors directories via inputs.conf
    │
    ▼
Forwards to Splunk Indexer / Splunk Cloud
(port 9997)
    │
    ▼
cdc.splunk-out monitors UF health
(port 8089 TLS, port 10001 HTTP)
```

```
┌─────────────────────────────────────────────────────────────────────┐
│  On-Prem Host                                                       │
│                                                                     │
│  ┌──────────────┐    CSV files    ┌──────────────────────────────┐  │
│  │ Flume        │───────────────▶│  /data/out/splunk/            │  │
│  │ Pipeline     │                │  ├── nios/dns/                │  │
│  └──────────────┘                │  ├── nios/rpz/                │  │
│                                  │  └── bloxone/                 │  │
│                                  └──────────┬───────────────────┘  │
│                                             │                       │
│                                             ▼                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  cdc.splunk-out Container                                    │   │
│  │  ┌────────────────────────┐  ┌────────────────────────────┐  │   │
│  │  │  Splunk UF (9.1.0)     │  │  Health Check Service      │  │   │
│  │  │  (splunkforwarderbase)  │  │  :10001/health             │  │   │
│  │  │                        │  │                            │  │   │
│  │  │  - inputs.conf         │  │  Checks:                   │  │   │
│  │  │  - outputs.conf        │  │  - UF port 8089 (TLS)     │  │   │
│  │  │  - supervisord         │  │  - splunkd process alive   │  │   │
│  │  │  - config_writer       │  │  - data dirs writable      │  │   │
│  │  │  - ib_control.reload   │  │  - forwarding status       │  │   │
│  │  │                        │  │                            │  │   │
│  │  │  Port 8089 (mgmt/TLS) │  │  Client cert auth:         │  │   │
│  │  │  Port 9997 (fwd out)   │  │  - client.pem              │  │   │
│  │  └────────────┬───────────┘  │  - client-key.pem          │  │   │
│  │               │              └────────────────────────────┘  │   │
│  └───────────────┼──────────────────────────────────────────────┘   │
│                  │                                                   │
└──────────────────┼───────────────────────────────────────────────────┘
                   │ port 9997
                   ▼
        ┌─────────────────────┐
        │  Customer Splunk    │
        │  Indexer / Cloud    │
        └─────────────────────┘
```

---

## Data Flow

| Step | Component | Action | Detail |
|------|-----------|--------|--------|
| 1 | Flume Pipeline | Produces CSV files | Writes to `/infoblox/data/out/splunk/{nios/dns, nios/rpz, bloxone}` |
| 2 | Splunk UF | Monitors directories | Configured via `inputs.conf` from `splunkforwarderbase` |
| 3 | Splunk UF | Forwards data | Sends to customer's Splunk deployment on port 9997 |
| 4 | cdc.splunk-out | Monitors health | Checks UF status on port 8089 via TLS mutual auth |

---

## Health Check Service

| Property | Value |
|----------|-------|
| HTTP Endpoint | `:10001/health` |
| Protocol | HTTP (health) / TLS (UF probe) |
| Client Cert | `/infoblox/etc/certs/client.pem` |
| Client Key | `/infoblox/etc/certs/client-key.pem` |

### Health Checks Performed

| Check | Description |
|-------|-------------|
| UF Port 8089 | Splunk UF management port reachable via TLS mutual auth |
| splunkd Process | Verifies `splunkd` process is alive |
| Data Dirs Writable | Confirms CSV output directories are writable |
| Forwarding Status | Validates UF is actively forwarding data |

---

## Data Directories

| Directory | Content |
|-----------|---------|
| `/infoblox/data/out/splunk/nios/dns/` | NIOS DNS query logs |
| `/infoblox/data/out/splunk/nios/rpz/` | NIOS RPZ logs |
| `/infoblox/data/out/splunk/bloxone/` | BloxOne data |

---

## Ports

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 8089 | TLS | Internal | Splunk UF management / health probe |
| 9997 | TCP | Outbound | Data forwarding to Splunk Indexer/Cloud |
| 10001 | HTTP | Inbound | Health check endpoint |

---

## Base Image

**`cdc.splunkforwarderbase` v2.1.3**

| Property | Value |
|----------|-------|
| Splunk UF Version | 9.1.0 |
| OS | Alpine Linux + glibc |
| Process Manager | supervisord |
| Config Writer | config_writer |
| Reload Mechanism | ib_control.reload |

### Template Variables

| Variable | Description |
|----------|-------------|
| `index` | Splunk index name |
| `sourcetype` | Splunk sourcetype for ingested data |
| `host` | Host identifier |
| `_meta` | Metadata fields |
| `disabled` | Enable/disable monitoring for a stanza |
| `followTail` | Start reading from tail of file (vs. beginning) |

---

## TLS Configuration

| File | Path | Purpose |
|------|------|---------|
| Client Certificate | `/infoblox/etc/certs/client.pem` | Mutual TLS client identity |
| Client Key | `/infoblox/etc/certs/client-key.pem` | Mutual TLS client private key |

---

## Dependencies

| Dependency | Role |
|------------|------|
| `cdc.splunkforwarderbase` | Base image — provides Splunk UF, supervisord, config_writer |
| `cdc.agent` | Cleanup of old CSV files |
| Flume Pipeline | Upstream data source — writes CSV to monitored directories |
| Config Manager | Delivers configuration (inputs.conf, outputs.conf parameters) |

---

## Key Differences from Other Output Services

| Aspect | cdc.splunk-out | cdc.siem-out / cdc.syslog-out |
|--------|---------------|-------------------------------|
| Kafka | **No** — on-prem only, no Kafka consumer | Yes — Kafka consumer based |
| Data Source | Flume CSV files on disk | Kafka topics |
| Forwarding | Splunk UF handles forwarding natively | Application sends via TCP/UDP/TLS |
| Role of Service | Health monitoring wrapper only | Active data consumer and sender |
| Base Image | `cdc.splunkforwarderbase` | Standard Go service |
