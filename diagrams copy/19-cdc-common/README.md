# CDC Common — Shared Go Library for CDC On-Prem Services

## Purpose

`cdc.common` is a **shared Go library** providing reusable packages for all CDC on-prem container services. It implements cross-cutting concerns: health checking, encryption/decryption, structured logging, file system monitoring, disk monitoring, configuration parsing, file cleanup/retention, utility functions, and mock Redis for testing.

This library is consumed as a Go dependency (`github.com/Infoblox-CTO/cdc.common`) by 12+ CDC services and is also packaged as a Helm chart for shared Kubernetes resources.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      cdc.common Library                      │
│                                                              │
│  ┌──────────┐  ┌───────────┐  ┌────────┐  ┌─────────────┐  │
│  │  health   │  │   crypt   │  │ logger │  │ datamonitor │  │
│  │ Process   │  │ AES-256   │  │ JSON   │  │  inotify    │  │
│  │ Network   │  │   GCM     │  │ logrus │  │  file size  │  │
│  │ TLS       │  │ scrypt    │  │        │  │  metrics    │  │
│  │ WAPI      │  │           │  │        │  │             │  │
│  └──────────┘  └───────────┘  └────────┘  └─────────────┘  │
│                                                              │
│  ┌──────────┐  ┌───────────┐  ┌────────┐  ┌─────────────┐  │
│  │ monitor  │  │    cfg    │  │cleanup │  │    util     │  │
│  │ disk vol │  │ flag/env  │  │retention│  │  Splunk     │  │
│  │ percent  │  │ JSON conf │  │threshold│  │  parsing    │  │
│  │ metrics  │  │ parsing   │  │ cleanup │  │  helpers    │  │
│  └──────────┘  └───────────┘  └────────┘  └─────────────┘  │
│                                                              │
│  ┌──────────────┐                                            │
│  │  mockredis   │                                            │
│  │  In-memory   │                                            │
│  │  Redis mock  │                                            │
│  └──────────────┘                                            │
└──────────────────────────────────────────────────────────────┘
         │
         │ imported by
         ▼
┌──────────────────────────────────────────────────────────┐
│  cdc.flume, cdc.splunk-out, cdc.siem-out, cdc.dns-in,  │
│  cdc.rpz-in, cdc.wapi-in, cdc.syslog-out, cdc.http-out,│
│  cdc.rest-out, cdc.grpc-out, cdc.reporting-out,         │
│  cdc.appbase, cdc.agent, cdc.etl, ...                   │
└──────────────────────────────────────────────────────────┘
```

## Data Flow

As a library, `cdc.common` does not have its own data flow. Each package provides functionality consumed by CDC services:

1. **health** → Called by Docker HEALTHCHECK in each on-prem container to verify processes, ports, network, and TLS endpoints
2. **crypt** → Called to encrypt config data in the cloud and decrypt it on-prem
3. **logger** → Initialized at service startup, all logs flow as structured JSON to stderr
4. **datamonitor** → Runs as a goroutine watching directories via inotify, writes size metrics to JSON files, reports to metrics collector
5. **monitor** → Runs as a metrics callback, periodically reports disk usage to metrics collector
6. **cfg** → Parsed at startup from flags/env/JSON config files
7. **cleanup** → Runs as a goroutine watching for new files, triggers retention-based cleanup when disk thresholds are exceeded
8. **util** → Utility functions called on demand for Splunk config parsing, file checks, PEM key decryption

## Key Files & Directory Structure

```
cdc.common/
├── Makefile              # Helm chart build/push (chart name: "cdc")
├── Jenkinsfile           # CI/CD pipeline
├── build/
│   └── build.properties.in
├── repo/                 # Helm chart for shared K8s resources
│
├── health/               # Health checking library
│   ├── health.go         # CheckProcess, CheckNetworkEndpoint, CheckTLSendpoint, CheckWapiStatus
│   ├── checklist.go      # Type definitions (Process, NetworkEndpoint, TLSEndpoint, Wapi)
│   ├── wapi_black_list.go # WAPI bad-credentials blacklisting with time window
│   └── README.md         # Usage documentation
│
├── crypt/                # Encryption/decryption
│   ├── crypt.go          # Encrypt(), Decrypt() using AES-256-GCM + scrypt KDF
│   └── test/             # Test files
│
├── logger/               # Structured logging
│   └── logger.go         # NewLogger() — JSON formatter with custom default fields
│
├── datamonitor/          # File system monitoring & size metrics
│   ├── metrics.go        # CdcMetrics, inotify watchers, size/count/timestamp metrics
│   ├── README.md         # Workflow documentation
│   └── test/             # Test files
│
├── monitor/              # Disk volume monitoring
│   └── metrics.go        # CheckCdcVolume(), CheckCdcVolumePercent(), GetDiskUsage()
│
├── cfg/                  # Configuration management
│   └── metrics_conf.go   # Configuration struct, flag parsing, JSON config file parsing
│
├── cleanup/              # File retention & disk cleanup
│   ├── config.go         # ReadConf() from env, ParseConfigFile() for JSON config
│   ├── disk.go           # Disk threshold checks, file expiry deletion, space calculation
│   └── monitor.go        # Init(), start(), inotify-based cleanup trigger loop
│
├── util/                 # Utility functions
│   └── health-util.go    # Splunk config parsing, file existence checks, PEM key decryption
│
└── mockredis/            # In-memory Redis mock for testing
    └── mockredis.go      # Set/Get/Del/LRange/LPush with TTL support
```

## Package Details

### `health` — Process & Endpoint Health Checking

Provides health check primitives used by Docker HEALTHCHECK scripts in all CDC on-prem containers.

| Function | Description |
|----------|-------------|
| `CheckProcess([]Process)` | Verifies processes are running with expected listening ports. Uses `/proc/<PID>/cmdline` matching with regex support. |
| `CheckNetworkEndpoint(NetworkEndpoint)` | TCP dial to host:port with configurable timeout (default 5s) |
| `CheckTLSendpoint(TLSEndpoint)` | TLS handshake with optional CA verification, client certs, server name check |
| `CheckWapiStatus(Wapi)` | HTTPS call to NIOS WAPI with bad-credentials blacklisting (120s window via `WAPI_BACKLIST_WINDOW_TIME` env) |

**Key types:**
```go
type Process struct { ProcessName string; Port []uint32 }
type NetworkEndpoint struct { Host string; Port int; Network string; DialTimeOut time.Duration }
type TLSEndpoint struct { Host string; Port int; ServerName string; RootCaPEM, ClientCertPem, ClientKeyPem []byte }
type Wapi struct { NiosHost, Username, Password string; RootCaPEM []byte; DialTimeOut time.Duration }
```

### `crypt` — AES-256-GCM Encryption

Provides symmetric encryption for CDC config data (passwords, credentials) using AES-256-GCM with scrypt key derivation.

| Function | Description |
|----------|-------------|
| `Encrypt(data string) (string, error)` | Encrypts data → hex-encoded ciphertext with appended salt |
| `Decrypt(data string) (string, error)` | Decrypts hex string → plaintext. Returns original if not valid hex (plaintext passthrough). |

**Implementation details:**
- Password: hardcoded `cdc-0nprem-Pa$$word`
- KDF: `scrypt.Key(password, salt, 32768, 8, 1, 32)` — 32-byte key
- Salt: 32 random bytes appended to ciphertext
- Nonce: Random, sized to GCM requirements
- Output: `hex(nonce + ciphertext + salt)`

### `logger` — JSON Structured Logging

Wraps logrus with a custom JSON formatter that injects default fields into every log entry.

```go
// Usage in any CDC service:
logger.NewLogger(map[string]interface{}{
    "name":       "cdc_size_metrics",
    "service_id": os.Getenv("SERVICE_ID"),
})
```

- Output: JSON to stderr
- Level: Configured via `LOG_LEVEL` env var (default: `info`)
- Every log line includes the default fields plus standard logrus fields

### `datamonitor` — inotify File System Monitoring

Monitors CDC data directories using `rjeczalik/notify` (inotify) for file events, tracks pending and processed data sizes, and reports metrics.

| Metric | Type | Description |
|--------|------|-------------|
| `cdc.pending.<metric>.size` | Gauge (MB) | Size of pending data files |
| `cdc.processed.<metric>.size` | Gauge (MB) | Size of processed data files |
| `cdc.total.events.delivered.to.<dest>` | Gauge | Count of events delivered |
| `cdc.<metric>.timestamp` | Gauge | Timestamp of last activity |

- Metrics read from JSON stat files (`/var/cache/cdc_metrics/size_metrics.json`)
- Supports recursive directory watching
- Configuration via JSON config file (monitor dirs, file extensions, events)
- Reports to `atlas.metrics.common` collector at configurable intervals

### `monitor` — Disk Volume Monitoring

Reports CDC volume disk usage metrics.

| Metric | Description |
|--------|-------------|
| `cdc.volume.used.MB` | CDC directory size in megabytes |
| `cdc.volume.used.percent` | CDC directory usage as percentage of total disk |

Uses `gopsutil/disk` for disk stats and `du -s` for directory size.

### `cfg` — Configuration Management

Centralizes flag/env config parsing for all CDC services.

| Config | Default | Description |
|--------|---------|-------------|
| `--log-level` | `info` | Log level |
| `--cdc-dir` | `/infoblox` | CDC root directory |
| `--cdc-stats-conf` | `/usr/local/share/monitor_dns_conf.json` | Metrics config file |
| `--metrics-check-interval` | `15s` | Metrics collection interval |
| `--container-id` | `cdc:common` | Container identifier |
| `--metrics-colletor-addr` | `172.17.0.1:8125` | Metrics collector address |
| `--app-agent-port` | `50057` | App agent port |

Also provides `ParseConfigFile()` for JSON-based monitor configuration with per-metric directory/event/extension settings.

### `cleanup` — Retention-Based File Cleanup

Monitors directories for new files and cleans up old files when disk thresholds are exceeded.

| Config (Env) | Default | Description |
|-------------|---------|-------------|
| `RETENTION_PERIOD_SEC` | `14400` (4h) | Maximum file age before deletion |
| `DISK_THRESHOLD_PCENT` | `90` | Overall disk usage threshold |
| `CDC_THRESHOLD_PCENT` | `70` | CDC-relative disk usage threshold |
| `CDC_DIRECTORY` | `/infoblox/data` | CDC data directory |
| `POLL_PERIOD_SEC` | `10` | Periodic cleanup interval |
| `CLEANUP_CONFIG_FILE` | `/etc/cleanup/config.json` | Cleanup JSON config |

**JSON Config structure:**
```json
{
  "priority": ["dir1", "dir2"],
  "multiplication_factor": {"pattern": 3},
  "filemapping": {"source": "target"},
  "monitor_extensions": [".avro", ".parquet"]
}
```

**Cleanup logic:**
1. Watches directories for file `Create` events via inotify
2. Calculates required space (file size × multiplication factor)
3. Checks if disk usage exceeds threshold (handles separate/shared partitions)
4. Deletes files older than retention period
5. Runs periodic cleanup every `POLL_PERIOD_SEC` when idle

### `util` — Splunk Config Parsing & Helpers

| Function | Description |
|----------|-------------|
| `ParseSplunkOutputConf(file)` | Parses Splunk `outputs.conf` format → `SplunkConfig` struct (servers, SSL paths, passwords) |
| `IsEnabledFileExists(file)` | Checks if container-enabled marker file exists |
| `IsContainerDisabled(file)` | Reads marker file to check if container is disabled |
| `GetDecryptedPrivateKey(...)` | Decrypts PEM-encoded private keys with password (PKCS#5) |

### `mockredis` — In-Memory Redis Mock

Thread-safe in-memory key-value store mimicking Redis operations for testing:
- `Set(key, value, ttl)`, `Get(key)`, `Del(key)` — Basic operations with TTL
- `LRange(key, start, stop)`, `LPush(key, values)` — List operations

## Configuration

The library itself is configured via the consuming services. The `cfg` package provides the central configuration struct that services use:

```go
cfg.Load()  // Parse flags
cfg.CdcConfig.ParseConfigFile(confFile)  // Parse JSON config
```

## Dependencies

| Dependency | Used By | Purpose |
|-----------|---------|---------|
| `github.com/sirupsen/logrus` | logger, crypt, cleanup | Structured logging |
| `github.com/rjeczalik/notify` | datamonitor, cleanup | inotify file system events |
| `github.com/shirou/gopsutil` | health, monitor | Process listing, disk stats |
| `golang.org/x/crypto/scrypt` | crypt | Key derivation for AES-256-GCM |
| `github.com/Infoblox-CTO/atlas.metrics.common` | datamonitor, monitor | Metrics collection framework |
| `github.com/pkg/errors` | health | Error wrapping |

## Consuming Services

The following CDC services import `cdc.common`:

| Service | Packages Used |
|---------|--------------|
| `cdc.flume` | health, crypt, logger, datamonitor, cfg, cleanup |
| `cdc.splunk-out` | health, crypt, logger, datamonitor, cfg, util |
| `cdc.siem-out` | health, crypt, logger, datamonitor, cfg, util |
| `cdc.dns-in` | health, logger, datamonitor, cfg |
| `cdc.rpz-in` | health, logger, datamonitor, cfg |
| `cdc.wapi-in` | health, logger, datamonitor, cfg |
| `cdc.syslog-out` | health, crypt, logger, datamonitor, cfg, util |
| `cdc.http-out` | health, logger, datamonitor, cfg |
| `cdc.rest-out` | health, logger, cfg |
| `cdc.grpc-out` | health, logger, cfg |
| `cdc.reporting-out` | health, logger, datamonitor, cfg |
| `cdc.appbase` | crypt, datamonitor, cfg, logger |
| `cdc.agent` | logger, cfg |
| `cdc.etl` | logger, cfg |

## Build & Deploy

As a library, `cdc.common` is imported via Go modules. It also has a Helm chart:

```bash
# Lint the shared Helm chart
make helm-lint

# Package the chart
make helm-archive

# Push to S3-based Helm repo
make push-chart
```

The library is versioned via Git tags. Services pin specific versions in their `go.mod` or `Gopkg.toml`.
