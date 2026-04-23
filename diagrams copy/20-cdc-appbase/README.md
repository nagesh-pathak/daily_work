# CDC AppBase — Base Docker Image for On-Prem CDC Containers

## Purpose

`cdc.appbase` is a **base Docker image** that provides the foundational runtime environment for all CDC on-prem containers. It packages common utilities, monitoring tools, config management scripts, and lifecycle management (`ib_control`) into Alpine Linux and Ubuntu base images. Every CDC on-prem service (Flume, Splunk-out, SIEM-out, DNS-in, RPZ-in, Syslog-out, HTTP-out, etc.) uses `FROM infobloxcto/cdc.appbase` as their starting layer.

The image includes two compiled Go binaries from `cdc.common` — the **datamonitor** (file size metrics) and **decrypt** (AES-256-GCM decryption) — along with Python scripts for config rendering, statistics accumulation, and file purging.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    cdc.appbase Docker Image                   │
│                                                              │
│  ┌─────────────── Go Builder Stage ────────────────┐        │
│  │  golang:1.10.0                                   │        │
│  │  Compiles: datamonitor, decrypt                  │        │
│  └──────────────────────────────────────────────────┘        │
│                       │                                      │
│                       ▼                                      │
│  ┌─────────────── Runtime Stage ───────────────────┐        │
│  │  alpine:3.7 (or ubuntu:18.04)                    │        │
│  │                                                   │        │
│  │  /usr/local/bin/                                  │        │
│  │  ├── datamonitor      (Go binary — file metrics) │        │
│  │  ├── decrypt          (Go binary — AES decrypt)  │        │
│  │  ├── ib_control       (bash — lifecycle mgmt)    │        │
│  │  ├── ib_control.stats (bash — stats collection)  │        │
│  │  ├── ib_control.purge (python — file purging)    │        │
│  │  ├── config_writer    (python — Jinja2 templating)│       │
│  │  ├── dcstats_accumulate.py (python — inotify stats)│      │
│  │  ├── echoLog.sh       (bash — JSON log helper)   │        │
│  │  ├── customlogger.py  (python — JSON logging)    │        │
│  │  └── size_metrics.sh  (bash — starts datamonitor)│        │
│  │                                                   │        │
│  │  /var/cache/cdc_metrics/  (metrics data dir)     │        │
│  │                                                   │        │
│  │  System packages: curl, python2, pip, bash,      │        │
│  │    jq, openssl, nfs-utils, inotify-tools, ...    │        │
│  └──────────────────────────────────────────────────┘        │
│                       │                                      │
│                       ▼                                      │
│        Used as base by all CDC on-prem containers            │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow

```
                    On-Prem Host
                         │
           ┌─────────────┼─────────────┐
           │             │              │
     ┌─────▼─────┐ ┌────▼────┐ ┌──────▼──────┐
     │Config Mgr │ │HostApp  │ │ Onprem      │
     │           │ │         │ │ Monitor     │
     └─────┬─────┘ └────┬────┘ └──────▲──────┘
           │             │              │
           ▼             ▼              │
     ┌────────────────────────────────────────────┐
     │          CDC Container (e.g. Flume)         │
     │  FROM infobloxcto/cdc.appbase               │
     │                                             │
     │  1. ib_control start                        │
     │     └─→ config_writer renders Jinja2        │
     │         templates from JSON config          │
     │     └─→ Starts application processes        │
     │     └─→ touch $SERVICE_STARTED              │
     │                                             │
     │  2. datamonitor (goroutine)                 │
     │     └─→ Watches /infoblox/data/ dirs        │
     │     └─→ Writes metrics to                   │
     │         /var/cache/cdc_metrics/              │
     │     └─→ Reports to onprem monitor ──────────┘
     │                                             │
     │  3. decrypt (on-demand)                     │
     │     └─→ Decrypts AES-256-GCM passwords     │
     │                                             │
     │  4. ib_control health                       │
     │     └─→ Docker HEALTHCHECK calls this       │
     │                                             │
     │  5. dcstats_accumulate.py                   │
     │     └─→ inotify-based pipeline stats        │
     │     └─→ ib_control.stats triggers output    │
     └────────────────────────────────────────────┘
```

## Key Files & Directory Structure

```
cdc.appbase/
├── Makefile               # Build alpine + ubuntu images, push, clean
├── Jenkinsfile            # CI/CD pipeline
├── CHANGELOG.md           # Version history (v0.0.1 → v2.1.6)
├── conf.json              # Sample Flume config JSON (sources, sinks, channels)
│
├── Docker/
│   ├── Dockerfile         # Alpine-based image (multi-stage build)
│   └── Dockerfile_ubuntu  # Ubuntu-based image (multi-stage build)
│
├── datamonitor/           # Go binary: file size metrics collection
│   ├── main.go            # Entry point: cfg.Load(), parse config, start monitoring
│   ├── Gopkg.toml/lock    # Dependencies
│   └── vendor/            # Vendored deps
│
├── decrypt/               # Go binary: AES-256-GCM password decryption
│   ├── main.go            # Entry point: flag parse, crypt.Decrypt(), print result
│   ├── Gopkg.toml/lock    # Dependencies
│   └── vendor/            # Vendored deps
│
└── bin/                   # Scripts copied into image at /usr/local/bin/
    ├── ib_control         # Main lifecycle script (start/stop/reload/health/backup/restore)
    ├── ib_control.stats   # Statistics collection (triggers dcstats_accumulate.py)
    ├── ib_control.purge   # File purging script (Python, regex-based cleanup)
    ├── config_writer.py   # Jinja2 template renderer for Flume/service configs
    ├── dcstats_accumulate.py # inotify-based file stats accumulator (Python)
    ├── echoLog.sh         # JSON structured log helper for bash scripts
    ├── customlogger.py    # Python JSON logger
    ├── size_metrics.sh    # Starts datamonitor binary with env config
    └── requirements.txt   # Python dependencies (pyinotify, requests, etc.)
```

### Script Details

#### `ib_control` — Container Lifecycle Management

The central script called by the host app for container lifecycle operations:

| Command | Action |
|---------|--------|
| `ib_control start` | Runs `ib_control.start` if exists, touches `$SERVICE_STARTED` marker |
| `ib_control stop` | Removes `$SERVICE_STARTED` marker, runs `ib_control.stop` |
| `ib_control reload` | Runs `ib_control.reload` for config reload |
| `ib_control state` | Returns 0 if `$SERVICE_STARTED` exists, 1 otherwise |
| `ib_control health` | Runs `ib_control.health` for Docker HEALTHCHECK |
| `ib_control stats` | Triggers stats collection via `dcstats_accumulate.py` |
| `ib_control purge` | Runs file purging via `ib_control.purge` |
| `ib_control backup` | Archives persistent data with GPG encryption |
| `ib_control restore` | Restores persistent data from GPG-encrypted backup |
| `ib_control getbundle` | Collects support bundle data |

Each CDC service can override specific subcommands by providing `ib_control.<subcommand>` scripts.

#### `config_writer.py` — Jinja2 Template Renderer

Renders Flume/service configurations from JSON config + Jinja2 templates:
- Reads `FLUME_JSON_CONFIG` environment variable for config source
- Supports filter parsing: IP ranges (CIDR), DNS views, query wildcards→regex, zone filtering
- Compares rendered configs against existing files to detect changes (return code 1 = changed, 0 = unchanged)
- Uses `netaddr` for IP/CIDR parsing
- Caches config lookups for performance

#### `dcstats_accumulate.py` — Pipeline Statistics

Uses `pyinotify` to watch data directories and accumulate file processing statistics:
- Tracks `files_processed`, `size_processed`, `size_pending`
- Responds to `SIGHUP` (write summary stats) and `SIGUSR2` (write detailed stats)
- Output: `/tmp/pipeline_stats` and `/tmp/pipeline_stats_detailed`

#### `datamonitor` (Go binary)

Compiled from `cdc.appbase/datamonitor/main.go`, uses `cdc.common/datamonitor` package:
- Waits for config file to exist and be non-empty
- Parses monitor config JSON
- Starts directory watchers via inotify
- Reports metrics to onprem monitor service at `$ONPREM_MONITOR_SVC:$ONPREM_MONITOR_PORT`

#### `decrypt` (Go binary)

Compiled from `cdc.appbase/decrypt/main.go`, uses `cdc.common/crypt` package:
- Takes `--password` flag with hex-encoded encrypted string
- Outputs decrypted plaintext to stdout
- If input is not valid hex (plaintext), returns it unchanged

### `echoLog.sh` — Structured JSON Logging for Bash

```bash
echoLog "message" "level"  # level: info|debug|warning|error|fatal|panic
# Output: {"level":"info","name":"script","msg":"message","service_id":"xxx","time":"2024/01/01 00:00:00"}
```

## Configuration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `SERVICE_STARTED` | Path to marker file (default: `/usr/local/etc/service_running`) |
| `SERVICE_ID` | Unique service identifier for metrics |
| `CONT_ID` | Container identifier |
| `FLUME_JSON_CONFIG` | Path to Flume JSON config file |
| `NET_MODE` | Network mode (`host` or bridge) |
| `ONPREM_MONITOR_SVC` | Onprem monitor service address |
| `ONPREM_MONITOR_PORT` | Onprem monitor service port |
| `IB_STATS_DIR` | Statistics directory for purge/stats |
| `IB_STATS_PATTERN` | File pattern for stats (default: `*`) |
| `STATS_SVC_NAME` | Stats service name |
| `HOST_IP` | Host IP for Docker API calls |
| `DOCKER_PORT` | Docker API port |

### Installed System Packages

**Alpine image:** curl, unzip, python2, py2-pip, bash, coreutils, cpio, dpkg, nfs-utils, cifs-utils, net-tools, openssl, perl, tar, tzdata, gcc, wget, jq, inotify-tools

**Ubuntu image:** curl, iproute2, unzip, python, python-pip, python-jinja2, python-netaddr, bash, coreutils, cpio, dpkg, nfs-kernel-server, net-tools, openssl, perl, tar, gcc, wget, jq

### Python Dependencies (requirements.txt)

- `pyinotify` — File system monitoring
- `python-json-logger` — JSON log formatting
- `requests` — HTTP client
- `jinja2` — Template rendering
- `netaddr` — IP/CIDR parsing

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| **alpine:3.7** / **ubuntu:18.04** | Base OS images |
| **golang:1.10.0** | Builder stage for Go binaries |
| **cdc.common/datamonitor** | File size metrics library |
| **cdc.common/crypt** | AES-256-GCM encryption library |
| **cdc.common/cfg** | Configuration parsing |
| **cdc.common/logger** | Structured JSON logging |
| **atlas.metrics.common** | Metrics collection framework |
| **pyinotify** | Python inotify wrapper |
| **jinja2** | Python template engine |
| **netaddr** | IP network parsing |

## Services Using This Base Image

The following CDC on-prem containers use `FROM infobloxcto/cdc.appbase`:

| Service | Description |
|---------|-------------|
| `cdc.flume` | Apache Flume agent for data collection |
| `cdc.splunk-out` | Splunk forwarder output |
| `cdc.siem-out` | SIEM CEF/LEEF output |
| `cdc.dns-in` | DNS log input |
| `cdc.rpz-in` | RPZ log input via syslog |
| `cdc.wapi-in` | WAPI/ipmeta input |
| `cdc.syslog-out` | Syslog CEF/LEEF output |
| `cdc.http-out` | HTTP output |
| `cdc.rest-out` | REST API output |
| `cdc.grpc-out` | gRPC output |
| `cdc.reporting-out` | Reporting output |

## Build & Deploy

```bash
# Build both Alpine and Ubuntu images
make build

# Build Alpine image only
make alpine-base

# Build Ubuntu image only
make ubuntu-base

# Push versioned images
make push

# Push latest tags
make push-latest

# Clean up local images
make clean
```

### Image Names

| Image | Base OS |
|-------|---------|
| `infobloxcto/cdc.appbase:<version>` | Alpine 3.7 |
| `infobloxcto/cdc.appbase.ubuntu:<version>` | Ubuntu 18.04 |

Images are versioned using Git tags (`git describe`). Both `:latest` and `:<git-tag>` tags are pushed.

### Directory Structure Created in Image

```
/usr/local/bin/           # All scripts and Go binaries
/usr/local/etc/           # SERVICE_STARTED marker location
/var/cache/cdc_metrics/   # Metrics data directory
```
