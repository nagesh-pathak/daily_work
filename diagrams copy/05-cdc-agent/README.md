# CDC Agent (cdc.agent)

## Overview

On-prem monitoring, disk cleanup, and health agent. **NOT a Kubernetes operator.** Runs as a Docker container with `supervisord` managing 3 processes: `cdcmonitor`, `cleanup`, `health`.

## Architecture

Docker container using `supervisord` to manage 3 child processes. Runs on each on-prem CDC host alongside other CDC containers.

```
┌─────────────────────────────────────────────┐
│           cdc.agent (Docker Container)       │
│                                              │
│  ┌─────────────────────────────────────────┐ │
│  │            supervisord                   │ │
│  │  ┌────────────┬──────────┬────────────┐ │ │
│  │  │ cdcmonitor │ cleanup  │   health   │ │ │
│  │  │ (watcher)  │ (disk)   │  (HTTP)    │ │ │
│  │  └────────────┴──────────┴────────────┘ │ │
│  └─────────────────────────────────────────┘ │
│                                              │
│         /infoblox/data/                      │
│         ├── in/   (input data)               │
│         └── out/  (output data)              │
└─────────────────────────────────────────────┘
```

## Processes

### 1. cdcmonitor (File Watcher)

- Uses `rjeczalik/notify` library for filesystem events (`inotify` on Linux)
- Monitors `/infoblox/data/` directory tree
- Events: `Create`, `Write`, `Remove`, `Rename`

**Watched Paths:**

| Path | Purpose |
|------|---------|
| `/infoblox/data/in/scp/` | Incoming SCP data from NIOS |
| `/infoblox/data/in/flume/` | Incoming Flume-staged data |
| `/infoblox/data/out/splunk/` | Outgoing Splunk UF data |
| `/infoblox/data/out/siem/` | Outgoing SIEM data |
| `/infoblox/data/out/cloud/` | Outgoing cloud upload data |
| `/infoblox/data/out/reporting/` | Outgoing reporting data |

### 2. cleanup (Disk Manager)

Prevents disk exhaustion on high-volume DNS/DHCP/RPZ traffic by enforcing retention policies and threshold-based cleanup.

**Thresholds & Defaults:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| Default retention | 4 hours | Time before files are eligible for deletion |
| Disk threshold | 90% | System-wide disk usage trigger |
| CDC threshold | 70% | Data partition usage trigger |
| Cleanup interval | 5 minutes | How often the cleanup cycle runs |
| Step reduction | 5 minutes | Incremental retention reduction when thresholds exceeded |

**Behavior:**
- Oldest files deleted first (FIFO)
- Pre-check: estimates required space before allowing new data ingestion
- Incremental: 5-minute step reduction in retention when thresholds are exceeded

**Output Estimation Multiplication Factors:**

| Pipeline | Factor | Description |
|----------|--------|-------------|
| `grpc_in` | 90× input | gRPC ingestion output estimate |
| `dns_in` | 10× input | DNS ingestion output estimate |

### 3. health (HTTP Health Server)

- HTTP endpoint: `:10001/health`
- Returns JSON health status

**Health Checks:**

| Check | Description |
|-------|-------------|
| Process liveness | Verifies child processes via `supervisord` |
| Disk space | Ensures disk usage is within thresholds |
| Container service status | Checks co-located CDC container health |
| Data directory accessibility | Validates `/infoblox/data/` is readable/writable |

Used by Kubernetes liveness probes and `atlas.onprem.health.reporter`.

## Data Directory Structure

### Input

| Path | Description |
|------|-------------|
| `/infoblox/data/in/scp/` | DNS captures (`.gz` from NIOS via SSH/SCP) |
| `/infoblox/data/in/flume/dns/` | Staged DNS data for Flume |
| `/infoblox/data/in/flume/rpz/` | Staged RPZ data for Flume |
| `/infoblox/data/in/flume/ipmeta/` | Staged IPAM metadata |

### Output

| Path | Description |
|------|-------------|
| `/infoblox/data/out/splunk/` | Splunk UF data (`nios/dns`, `nios/rpz`, `bloxone`) |
| `/infoblox/data/out/siem/` | SIEM data (`nios/dns/{cef,leef}`) |
| `/infoblox/data/out/cloud/` | Cloud upload data (`{dns,rpz,ipmeta}`) |
| `/infoblox/data/out/reporting/` | Reporting data |

## Role in CDC Architecture

- Runs on each on-prem CDC host as a Docker container
- Works with `atlas.onprem.health.reporter` for cloud-reported health
- Critical for preventing disk exhaustion on high-volume DNS/DHCP/RPZ traffic
- Coexists with `grpc-in`, `flume`, `splunk-out`, `dns-in`, etc. containers

## Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `rjeczalik/notify` | Cross-platform filesystem event monitoring |
| `supervisord` | Process management (runs 3 child processes) |
| `atlas.onprem.health.reporter` | Health aggregation and cloud reporting |

## Key Packages

| Package | Purpose |
|---------|---------|
| `cmd/` | Entry points for `cdcmonitor`, `cleanup`, `health` |
| `pkg/monitor/` | File system monitoring logic |
| `pkg/cleanup/` | Disk cleanup and retention management |
| `src/` | Core agent logic |
