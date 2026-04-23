# CDC API Service (`cdc.api`)

## Purpose

Central configuration hub for CDC flows. Manages container configs, ETL filters, and flow mappings across the entire CDC pipeline.

### Managed Containers

**Source:** `dns_in`, `rpz_in`, `ipmeta_in`, `grpc_in`
**Destination:** `grpc_out`, `siem_out`, `splunk_out`, `splunkcloud_out`, `reporting_out`, `http_out`, `soar_light`
**Orchestrator:** `flume`

## APIs

### Config Management

| Method | Endpoint                        | Description                        |
|--------|---------------------------------|------------------------------------|
| POST   | `/cdc/v1/config/{container}`    | Create/update container config     |
| GET    | `/cdc/v1/config/{container}`    | Retrieve container config          |
| DELETE | `/cdc/v1/config/{container}`    | Delete container config            |

### Status

| Method | Endpoint                        | Description                        |
|--------|---------------------------------|------------------------------------|
| POST   | `/cdc/v1/status/{container}`    | Update container status            |
| GET    | `/cdc/v1/status/{container}`    | Get container status               |

### ETL Filters

| Method | Endpoint                        | Description                        |
|--------|---------------------------------|------------------------------------|
| POST   | `/cdc/v1/etl/{container}`       | Create ETL filter                  |
| GET    | `/cdc/v1/etl/{container}`       | Get ETL filter                     |
| PUT    | `/cdc/v1/etl/{container}`       | Update ETL filter                  |
| DELETE | `/cdc/v1/etl/{container}`       | Delete ETL filter                  |

## Database

**Engine:** PostgreSQL (`cdc-db`)

### Tables

| Table            | Purpose                                                    |
|------------------|------------------------------------------------------------|
| `cdc_config`     | Versioned container configs with auto-increment versioning |
| `etl`            | Destination ETL filter definitions                         |
| `flow_mapping`   | Flow → container → ophid mappings                          |

### Config Versioning

- Auto-increment version per `ophid/container` combination via DB triggers
- Duplicate config detection returns **409 Conflict**

### Deletion Model

- Deletion creates a new config entry with `{"delete":"true"}` marker
- Sets `status_code=98` to signal downstream removal

## Dapr PubSub Integration

- **Subscribes to:** `cdc-flow-{env}` (receives flow events)
- **Publishes to:** `cm-{container}-{env}` (12 topics, one per container type)

```
cdc-flow-{env}  ──►  cdc.api  ──►  cm-dns_in-{env}
                                    cm-rpz_in-{env}
                                    cm-ipmeta_in-{env}
                                    cm-grpc_in-{env}
                                    cm-grpc_out-{env}
                                    cm-siem_out-{env}
                                    cm-splunk_out-{env}
                                    cm-splunkcloud_out-{env}
                                    cm-reporting_out-{env}
                                    cm-http_out-{env}
                                    cm-soar_light-{env}
                                    cm-flume-{env}
```

## Service Integrations

| Service                | Integration Type | Role                                     |
|------------------------|------------------|------------------------------------------|
| **CDC Flow API**       | gRPC             | Flow lifecycle and orchestration          |
| **Config Manager**     | —                | Upstream config source                    |
| **Status Service**     | —                | Container status tracking                 |
| **HostApp Service**    | —                | Host application management               |

## ETL Filters

Applied to **destination containers only**. Available filter fields:

| Filter         | Description                          |
|----------------|--------------------------------------|
| `client_ip[]`  | Filter by client IP addresses        |
| `dns_view[]`   | Filter by DNS view names             |
| `query[]`      | Filter by DNS query patterns         |
| `member[]`     | Filter by member identifiers         |

## Template Rendering

Uses **Go templates** per container type to generate Flume configuration files. Each container has its own template that produces the appropriate Flume agent config.

## Ports

| Port   | Protocol     | Purpose                |
|--------|--------------|------------------------|
| `9090` | gRPC         | Internal gRPC service  |
| `8080` | HTTP (REST)  | REST gateway           |
| `8082` | HTTP (Dapr)  | Dapr sidecar           |
