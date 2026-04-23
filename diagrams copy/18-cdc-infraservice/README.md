# CDC InfraService — gRPC/REST Configuration Service for On-Prem

## Purpose

`cdc.infraservice` is a **cloud-side gRPC/REST microservice** that manages infrastructure configurations for CDC on-prem containers (primarily Flume). It stores configuration JSON in PostgreSQL, renders it through Go templates into runnable Flume configs, and publishes change notifications via Dapr PubSub so that Config Manager can deliver updated configurations to on-prem hosts.

The service exposes two gRPC services:
- **CdcInfra** — Used by the CDC App Service (cloud UI) to create configurations and check status
- **CdcInfraConfig** — Used by Config Manager to retrieve rendered configurations and update delivery status

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Cloud (K8s)                              │
│                                                                 │
│  ┌──────────┐    REST :8080     ┌──────────────────┐           │
│  │ CDC App  │ ───────────────►  │  cdc.infraservice │           │
│  │ Service  │    gRPC :9090     │                    │          │
│  └──────────┘ ◄─────────────── │  ┌──────────────┐ │          │
│                                 │  │ CdcInfra     │ │          │
│                                 │  │  POST /config│ │          │
│                                 │  │  GET /status │ │          │
│                                 │  ├──────────────┤ │          │
│                                 │  │CdcInfraConfig│ │          │
│                                 │  │  GET /config │ │          │
│                                 │  │  POST /status│ │          │
│                                 │  └──────┬───────┘ │          │
│                                 │         │         │          │
│                                 │  ┌──────▼───────┐ │          │
│                                 │  │  PostgreSQL  │ │          │
│                                 │  │  (GORM ORM)  │ │          │
│                                 │  └──────────────┘ │          │
│                                 │         │         │          │
│                                 │  ┌──────▼───────┐ │          │
│                                 │  │ Go Template  │ │          │
│                                 │  │ niospack.tmpl│ │          │
│                                 │  └──────────────┘ │          │
│                                 └────────┬──────────┘          │
│                                          │ PubSub              │
│                                 ┌────────▼──────────┐          │
│                                 │  Atlas PubSub     │          │
│                                 │  topic: cm-cdc-   │          │
│                                 │         infra     │          │
│                                 └────────┬──────────┘          │
│                                          │                     │
│                                 ┌────────▼──────────┐          │
│                                 │  Config Manager   │          │
│                                 │  (subscriber)     │          │
│                                 └────────┬──────────┘          │
└──────────────────────────────────────────┼─────────────────────┘
                                           │
                              ┌────────────▼────────────┐
                              │   On-Prem Host (OPHID)  │
                              │   Flume / CDC Containers│
                              └─────────────────────────┘
```

## Data Flow

### 1. Configuration Creation (App Service → InfraService)
1. CDC App Service sends `POST /config` with `{ophid, app_name, config}` (JSON config string)
2. InfraService creates a `config_status` entry with status "Configuration Ready"
3. Stores config in `cdc_infra_etl_config` table; DB trigger auto-increments `version` per ophid
4. Publishes `PubSubConfigObject{ophid, version, appName}` to topic `cm-cdc-infra`
5. Returns the created record with auto-assigned version

### 2. Config Retrieval (Config Manager → InfraService)
1. Config Manager receives PubSub notification, calls `GET /config/{ophid}/{version}`
2. InfraService queries `cdc_infra_etl_config` for the config JSON
3. Renders the JSON through `niospack.tmpl` Go template (populates Flume agent sources/sinks/channels)
4. Returns rendered config as base64-encoded bytes in `ConfigObject`

### 3. Status Update (Config Manager → InfraService)
1. After delivering config to on-prem, Config Manager calls `POST /config/status` with delivery status
2. InfraService updates the `config_status` table

### 4. Status Check (App Service → InfraService)
1. App Service calls `GET /config/status/{ophid}/{app_name}`
2. InfraService joins `cdc_infra_etl_config` → `config_status` to return current delivery status

## Key Files & Directory Structure

```
cdc.infraservice/
├── Makefile                     # Build, test, docker, protobuf targets
├── Dockerfile                   # (empty — see docker/)
├── Gopkg.toml / Gopkg.lock     # dep dependency management
├── cmd/
│   └── server/
│       ├── main.go              # Entry point: PubSub setup, serve gRPC + REST
│       ├── config.go            # All flag/env defaults (ports, DB, PubSub, auth)
│       ├── grpc.go              # gRPC server with middleware chain
│       └── swagger.go           # Swagger file serving handler
├── pkg/
│   ├── pb/
│   │   ├── cdcInfra.proto       # Protobuf service definitions (2 services, 4 RPCs)
│   │   ├── cdcInfra.pb.go       # Generated protobuf code
│   │   ├── cdcInfra.pb.gorm.go  # Generated GORM model code
│   │   ├── cdcInfra.pb.gw.go    # Generated gRPC-Gateway code
│   │   ├── cdcInfra.pb.validate.go        # Generated validation
│   │   ├── cdcInfra.pb.atlas.validate.go  # Atlas validation
│   │   └── cdcInfra.swagger.json          # Generated Swagger spec
│   └── svc/
│       └── zserver.go           # Service implementation (CreateInfraConfig, GetInfraConfig, etc.)
├── template/
│   └── niospack.tmpl            # Go template for Flume agent config (sources, sinks, channels)
├── db/
│   └── migrations/
│       ├── 0001_infra_config.up.sql    # Create tables, triggers, functions
│       └── 0001_infra_config.down.sql  # Drop tables and triggers
├── deploy/
│   ├── cdc-infraservice.yaml           # K8s Deployment + Service
│   ├── cdc-infraservice-migrations.yaml # K8s Pod for DB migration
│   ├── cdc-infraservice-secrets.yaml   # K8s Secret for DB credentials
│   └── config.yaml                     # Application config (YAML)
├── docker/
│   └── Dockerfile               # Multi-stage build (Go 1.10 → Alpine)
├── utils/
│   └── utils.go                 # LogFields structured logging helper
└── vendor/                      # Vendored Go dependencies
```

### Protobuf Service Definitions

**Service: CdcInfra** (exposed to App Service):
| RPC | HTTP | Description |
|-----|------|-------------|
| `CreateInfraConfig` | `POST /config` | Create config (ophid, app_name, config JSON) |
| `GetConfigStatus` | `GET /config/status/{ophid}/{app_name}` | Check config delivery status |

**Service: CdcInfraConfig** (exposed to Config Manager):
| RPC | HTTP | Description |
|-----|------|-------------|
| `GetInfraConfig` | `GET /config/{ophid}/{version}` | Retrieve rendered config (`version=latest` supported) |
| `UpdateConfigStatus` | `POST /config/status` | Update delivery status from on-prem |

### Database Schema

**Table: `cdc_infra_etl_config`**
| Column | Type | Notes |
|--------|------|-------|
| `id` | serial PK | Auto-increment |
| `ophid` | text NOT NULL | On-prem host identifier |
| `version` | bigint NOT NULL | Auto-set by `set_version()` trigger per ophid |
| `app_name` | text NOT NULL | Application name (e.g., "CDC") |
| `config` | text NOT NULL | JSON configuration string |
| `config_status_id` | int FK → config_status(id) | Links to delivery status |
| `created_at` / `updated_at` | timestamptz | Auto-managed by triggers |
| UNIQUE(ophid, version) | | Ensures version uniqueness per host |

**Table: `config_status`**
| Column | Type | Notes |
|--------|------|-------|
| `id` | serial PK | Auto-increment |
| `status` | text | Delivery status message |
| `created_at` / `updated_at` | timestamptz | Auto-managed by triggers |

**DB Triggers:**
- `set_version()` — Auto-increments version per ophid on INSERT
- `set_updated_at()` — Sets `updated_at` on INSERT/UPDATE

### Go Template: niospack.tmpl

The template renders Flume agent configuration with conditional source/sink/channel blocks:
- **Sources**: `wapi` (WAPI/ipmeta), `dns_in` (DNS logs), `syslog` (RPZ via syslog TCP:514)
- **Sinks**: `wapi_sink` (cloud parquet), `dns_sink` (cloud DNS), `syslog_sink` (RPZ), `splunk_sink`, `reporting_sink`, `siem_sink`
- **Channels**: Memory channels connecting sources to sinks
- Uses `getValuesFromKey` helper to conditionally include sections based on config JSON

## Configuration

### Server Ports
| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 | HTTP/REST | gRPC-Gateway (REST API) |
| 8081 | HTTP | Internal health/readiness (`/health`, `/ready`) |
| 9090 | gRPC | Native gRPC API |

### Key Config Flags (cmd/server/config.go)

| Flag | Default | Description |
|------|---------|-------------|
| `--server.port` | `9090` | gRPC server port |
| `--gateway.port` | `8080` | REST gateway port |
| `--gateway.endpoint` | `/cdc.infraservice/v1/` | REST URL prefix |
| `--database.type` | `postgres` | Database type |
| `--database.address` | `0.0.0.0` | PostgreSQL host |
| `--database.port` | `5432` | PostgreSQL port |
| `--atlas.pubsub.address` | `pubsub.atlas` | PubSub service address |
| `--atlas.pubsub.port` | `5555` | PubSub service port |
| `--atlas.pubsub.publish` | `cm-cdc-infra` | PubSub topic for config notifications |
| `--logging.level` | `debug` | Log level |

### Environment Variables (K8s Deployment)

Database credentials are injected via K8s Secret `cdc-infra-db-secrets`:
- `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_SSLMODE`

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| **PostgreSQL** | Config and status storage |
| **Atlas PubSub** (gRPC) | Publishes config change notifications to `cm-cdc-infra` topic |
| **atlas-app-toolkit** | gRPC middleware (request ID, logging, validation, GORM transactions, health checks) |
| **protoc-gen-gorm** | Auto-generates GORM models from protobuf |
| **grpc-gateway** | REST reverse proxy for gRPC services |
| **protoc-gen-atlas-validate** | Request validation interceptor |
| **GORM** (jinzhu) | ORM for PostgreSQL |
| **Config Manager** | Subscribes to PubSub, retrieves configs, delivers to on-prem |
| **atlas-gentool** (Docker `infoblox/atlas-gentool:v15`) | Protobuf code generation |

### gRPC Middleware Chain

```
RequestID → Logrus Logging → Atlas Validation → Gateway Collection Ops → GORM Transaction
```

## Build & Deploy

```bash
# Generate protobuf code (requires atlas-gentool Docker image)
make protobuf

# Run tests
make test

# Build Docker image (multi-stage: Go 1.10 builder → Alpine runner)
docker build -f docker/Dockerfile -t infobloxcto/cdc.infraservice:latest .

# Push image
make push

# Deploy DB migrations (run as K8s Pod)
kubectl apply -f deploy/cdc-infraservice-secrets.yaml
kubectl apply -f deploy/cdc-infraservice-migrations.yaml

# Deploy service
kubectl apply -f deploy/cdc-infraservice.yaml
```

The Docker image includes:
- Server binary at `/bin/server`
- Swagger JSON at `/www/cdc.infraservice.swagger.json`
- Go templates at `/template/`
- DB migrations at `/db/migrations/`
