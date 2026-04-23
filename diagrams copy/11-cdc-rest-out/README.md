# CDC REST-Out (cdc.rest-out)

## Overview

Python-based uploader service. **On-prem only.** Uploads Parquet/Avro files from on-prem to cloud via HTTP POST. Uses `grequests` for async parallel uploads.

## Architecture

```
Flume CloudFileSink → /data/out/cloud/ → Directory watcher → grequests uploader → Cloud REST API → Kafka/Cloud pipeline
```

## Data Flow

1. Flume CloudFileSink writes Parquet files to `/infoblox/data/out/cloud/{dns,rpz}`
2. wapi-in writes Avro files to `/infoblox/data/out/cloud/ipmeta/`
3. Directory watcher detects new files
4. `grequests` uploads files asynchronously via HTTP POST
5. Cloud REST API receives and processes

## Input Directories

| Directory | Format | Content-Type | X-Data-Type | Notes |
|-----------|--------|-------------|-------------|-------|
| `/infoblox/data/out/cloud/dns/` | Parquet | `application/octet-stream` | `dns` | DNS query data |
| `/infoblox/data/out/cloud/rpz/` | Parquet | `application/octet-stream` | `rpz` | RPZ hit data |
| `/infoblox/data/out/cloud/ipmeta/` | Avro | `application/octet-stream` | `ipmeta` | IP metadata; `X-Snapshot: true/false` |

## IPMeta Special Handling

- Uses **Avro** format (not Parquet)
- Snapshot vs incremental distinguished by `X-Snapshot` header
- Different upload handling from DNS/RPZ

## HTTP Headers

| Header | Value | Purpose |
|--------|-------|---------|
| `Content-Type` | `application/octet-stream` | Binary file upload |
| `X-Data-Type` | `dns` / `rpz` / `ipmeta` | Identifies data category |
| `X-Snapshot` | `true` / `false` | IPMeta only — snapshot vs incremental |
| `Authorization` | `Bearer <token>` | Auth token from Config Manager |

## Retry Mechanism

- Failed uploads → `/retry/` directory
- `run_retry.sh` re-attempts uploads on configurable schedule
- Exponential backoff for failed attempts

## Configuration

| File | Purpose |
|------|---------|
| `/infoblox/etc/rest-out.json` | Upload URL, auth, batch size |

- **Auth:** Bearer token from Config Manager

## Python Dependencies

| Package | Purpose |
|---------|---------|
| `grequests` | gevent-based async HTTP |
| `requests` | HTTP client |
| `watchdog` | Filesystem monitoring |
| `pyarrow` | Parquet/Avro reading |

## Dependencies

| Component | Role |
|-----------|------|
| Flume CloudFileSink | Data source — writes Parquet/Avro to watched directories |
| `data.exporter.kafka` / Cloud REST API | Upload target |
| `cdc.agent` | Cleanup of uploaded files |
| Config Manager | Config and auth token delivery |
