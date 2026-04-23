# CDC gRPC-Out Service (`cdc.grpc-out`)

## Purpose

File ingestion and forwarding service that monitors directories for Parquet files and uploads them via gRPC to **ti-proxy-grpc**, which forwards data to Kafka. Handles three data types: **dns**, **ipmeta**, and **rpz** (all `.parquet` files).

## Data Flow

```
Source directories
  /infoblox/data/out/cloud/dns/
  /infoblox/data/out/cloud/ipmeta/
  /infoblox/data/out/cloud/rpz/
        │
        ▼
File monitor (rjeczalik/notify)
        │
        ▼
Worker pool dispatcher (min 3 workers)
        │
        ▼
File chunking (3,774,873 bytes/chunk)
        │
        ▼
gRPC bidirectional stream
        │
        ▼
ti-proxy-grpc → Kafka
```

## Data Types

| Type     | Directory                              | File Pattern                                      |
|----------|----------------------------------------|---------------------------------------------------|
| dns      | `/infoblox/data/out/cloud/dns/`        | `*.parquet`                                       |
| ipmeta   | `/infoblox/data/out/cloud/ipmeta/`     | `ipmeta-{timestamp}-{update_id}.parquet`          |
| rpz      | `/infoblox/data/out/cloud/rpz/`        | `*.parquet`                                       |

### IPMeta Special Handling

- Filename pattern: `ipmeta-{timestamp}-{update_id}.parquet`
- Adds custom gRPC headers:
  - `X-DC-SyncType` — snapshot vs incremental
  - `X-DC-SnapshotTS` — snapshot timestamp
  - `X-DC-UpdateID` — incremental update identifier
- Supports both **snapshot** and **incremental update** modes

## Error Handling

| Outcome  | Action                                  |
|----------|-----------------------------------------|
| Success  | Delete the source file                  |
| Failure  | Move file to `transfer/` directory      |
| Retry    | Re-attempt every **1 minute**           |

## Configuration

**Config file:** `/opt/grpc_out/conf/grpc_out.json`

Contains `log_types` mapping that defines monitored directories and their associated data types.

### CLI Flags

| Flag                          | Default     | Description                      |
|-------------------------------|-------------|----------------------------------|
| `--ti-proxy-grpc.host`        | `0.0.0.0`  | ti-proxy-grpc host address       |
| `--ti-proxy-grpc.port`        | `9090`      | ti-proxy-grpc port               |
| `--goroutines.worker.min`     | `3`         | Minimum worker pool size         |
| `--context.cancel.timeout`    | `2m`        | Context cancellation timeout     |

## Proto Definition

```protobuf
service TiProxyGrpc {
  rpc Upload(stream UploadRequest) returns (...);
  rpc Check(HealthCheckRequest) returns (...);
}
```

- **Upload** — bidirectional streaming RPC for file chunk uploads
- **Check** — health check endpoint

## Health

- **HTTP health endpoint:** `http://127.0.0.1:10001/health`

## Process Management

Managed by **supervisord** with two processes:

1. **server** — gRPC client and upload logic
2. **datamonitor** — file system watcher and dispatcher

## Key Packages

| Package          | Responsibility                              |
|------------------|---------------------------------------------|
| `client/`        | gRPC client for ti-proxy-grpc communication |
| `monitor/`       | File system monitoring (notify-based)       |
| `health/`        | HTTP health check server                    |
| `config/`        | Configuration loading and parsing           |
| `datamonitor/`   | Data directory watcher and file dispatcher  |

## Dependencies

| Dependency              | Role                                  |
|-------------------------|---------------------------------------|
| **ti-proxy-grpc**       | Upstream gRPC receiver (→ Kafka)      |
| **cdc.common**          | Shared CDC utilities and types        |
| **atlas.metrics.common**| Prometheus metrics integration        |
| **atlas.tls.auth**      | mTLS authentication                   |
