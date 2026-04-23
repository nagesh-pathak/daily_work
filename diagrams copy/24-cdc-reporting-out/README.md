# CDC Reporting-Out

## Purpose

CDC Reporting-Out is a **Splunk Universal Forwarder (UF) wrapper** specifically designed for the **NIOS Reporting** destination type. Unlike `cdc.splunk-out` (customer Splunk) and `cdc.siem-out` (customer SIEM in CEF/LEEF format), this container forwards processed DNS and RPZ data back to the **NIOS Grid's built-in Reporting Server** using Splunk's native protocol.

The key differentiator is its **automatic registration with the NIOS Grid**: the container generates SSL certificates, registers itself as a Data Connector with the Grid via WAPI, retrieves Reporting Server indexer details, and signs the forwarder certificate — all without manual intervention.

### Comparison with Other Splunk-Based Outputs

| Feature | `cdc.reporting-out` | `cdc.splunk-out` | `cdc.siem-out` |
|---------|---------------------|------------------|----------------|
| **Destination** | NIOS Reporting Server | Customer Splunk Instance | Customer SIEM (Splunk-based) |
| **Data Format** | Native CSV | Native CSV | CEF / LEEF |
| **SSL Certs** | Auto-generated & Grid-signed | Customer-provided | Customer-provided |
| **Registration** | Auto via WAPI (`datacollector:activate`) | Manual config | Manual config |
| **Health Port** | 9006 | 10001 | 10001 |
| **Base Image** | `cdc.splunkforwarderbase` | `cdc.splunkforwarderbase` | `cdc.splunkforwarderbase` |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    cdc.reporting-out Container               │
│                                                              │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐  │
│  │  supervisord  │  │ uf-main.sh    │  │ health binary    │  │
│  │  (PID 1)     │──│ (Splunk UF    │  │ (Go, port 9006)  │  │
│  │              │  │  lifecycle)    │  │                  │  │
│  └──────┬───────┘  └───────┬───────┘  └──────────────────┘  │
│         │                  │                                 │
│  ┌──────┴───────┐  ┌───────┴───────┐  ┌──────────────────┐  │
│  │ datamonitor  │  │ ib_control    │  │ generate_cert    │  │
│  │ (metrics     │  │ .reload       │  │ _register.py     │  │
│  │  collector)  │  │ (config mgr)  │  │ (WAPI + SSL)     │  │
│  └──────────────┘  └───────────────┘  └──────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │              Splunk Universal Forwarder 9.1.0            ││
│  │  splunkd (port 8089) → monitors /infoblox/data/out/     ││
│  │  reporting/{nios/dns, nios/rpz, bloxone}                ││
│  └──────────────────────────────────────────────────────────┘│
│                                                              │
│  Base Image: infobloxcto/cdc.splunkforwarderbase:latest      │
└───────────────────────────┬─────────────────────────────────┘
                            │ Splunk TCP (TLS)
                            ▼
                 ┌─────────────────────┐
                 │ NIOS Reporting      │
                 │ Server (Grid)       │
                 │ (Splunk Indexer)    │
                 └─────────────────────┘
```

## Data Flow

1. **Upstream CDC components** (dns-in, rpz-in, grpc-in) write processed data files into monitored directories on the shared host volume.
2. **Splunk UF** (`splunkd`) monitors the following directories via `inputs.conf`:
   - `/infoblox/data/out/reporting/nios/dns/` — NIOS DNS query/response logs
   - `/infoblox/data/out/reporting/nios/rpz/` — NIOS RPZ (Response Policy Zone) hit logs
   - `/infoblox/data/out/reporting/bloxone/` — BloxOne Threat Defense data
3. **On startup**, `ib_control.reload` invokes `config_writer` to render the Jinja2 template (`reporting_out.tmpl`) into Splunk configuration files.
4. **If Splunk status is "enabled"**, `generate_cert_register.py` runs:
   - Retrieves the on-prem host IP via the host manager REST API
   - Registers the Data Connector with NIOS Grid via WAPI (`datacollector:activate`)
   - Calls `reporting:getinfo` to get indexer IP/port and data types
   - Generates a CSR (`openssl req`) and has it signed by the Grid (`reporting:signcertificate`)
   - Writes CA cert, forwarder PEM, and `outputs.conf` SSL password
5. **Splunk UF** starts and forwards data to the Grid's Reporting indexer(s) over TLS.
6. **Health binary** (Go, port 9006) periodically validates:
   - `splunkd` process is running on port 8089
   - TLS connectivity to Reporting Server indexer(s)
   - WAPI connectivity to the Grid

## Key Files & Directory Structure

### Source Repository

```
cdc.reporting-out/
├── Dockerfile                    # Multi-stage: Go health binary + splunkforwarderbase
├── Makefile                      # Docker build/push with SPLUNK_INSTANCE_GUID
├── health/
│   ├── main.go                   # Health check server (port 9006)
│   └── vendor/                   # Go dependencies (cdc.common/health, cdc.common/util)
├── src/
│   ├── generate_cert_register.py # WAPI registration & SSL cert generation
│   └── ib_control.reload         # Config reload: calls config_writer + cert registration
└── deploy/
    └── docker-compose.yml        # Deployment manifest with volume mounts
```

### Runtime Container Layout

```
/opt/splunkforwarder/              # SPLUNK_HOME
├── bin/splunk                     # Splunk UF binary
├── etc/
│   ├── system/local/              # Active Splunk configs (inputs.conf, outputs.conf, etc.)
│   │   └── .tmp/                  # Staging dir for configs before activation
│   │       ├── cacert.pem         # Grid CA certificate
│   │       ├── forwarder.pem      # Signed forwarder certificate + private key
│   │       └── outputs.conf       # Output config with sslPassword
│   ├── supervisord.conf           # Process manager config
│   └── log.cfg                    # Splunk logging configuration
├── var/log/splunk/                # Splunk runtime logs
└── uf-main.sh, uf-restart.sh     # Lifecycle scripts (from base image)

/opt/reporting_out/conf/           # CONFIG_TEMPLATE_DIRECTORY
├── reporting_out.tmpl             # Jinja2 config template
├── grid_info.json                 # NIOS Grid connection info (address, username, password)
├── monitor_conf.json              # Data monitoring configuration
└── version                        # Config version tracker

/infoblox/data/out/reporting/      # IB_STATS_DIR (bind-mounted from host)
├── nios/dns/                      # NIOS DNS log files
├── nios/rpz/                      # NIOS RPZ log files
└── bloxone/                       # BloxOne data files

/infoblox/var/splunk_status        # "enabled" or "disabled"
/var/cache/cdc_metrics/            # Metrics output directory
├── reportingnios_dns/             # DNS metrics (size_metrics.json, fileinfo.json)
├── reportingnios_rpz/             # RPZ metrics
└── reportingbloxone/              # BloxOne metrics
/bin/health                        # Health check binary
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG_TEMPLATE_FILE` | `reporting_out.tmpl` | Jinja2 template filename |
| `CONFIG_TEMPLATE_DIRECTORY` | `/opt/reporting_out/conf` | Template directory |
| `GRID_CONF` | `/opt/reporting_out/conf/grid_info.json` | NIOS Grid connection info |
| `CA_CERT` | `.../.tmp/cacert.pem` | Path for Grid CA certificate |
| `FORWARDER_PEM` | `.../.tmp/forwarder.pem` | Path for signed forwarder PEM |
| `OUTPUT_CONF` | `.../.tmp/outputs.conf` | Path for Splunk outputs config |
| `UUID` | `95` | Data Connector unique ID for Grid registration |
| `SPLUNK_INSTANCE_GUID` | _(build arg)_ | SHA1-based UUID for Splunk instance |
| `CONT_ID` | `cdc:reporting` | Container identifier for metrics |
| `CONTAINER_NAME` | `reporting_out` | Container name |
| `ONPREM_MONITOR_PORT` | `8125` | On-prem metrics monitor port |
| `ONPREM_HOSTMANAGER_PORT` | `8126` | Host manager REST API port |
| `LOG_LEVEL` | `INFO` | Logging verbosity |

### SSL Certificate Flow

1. `generate_cert_register.py` generates an RSA-2048 CSR with subject `/CN=universal-forwarder`
2. Private key is AES-128 encrypted with a random password
3. CSR is submitted to Grid via `reporting:signcertificate` WAPI call
4. Grid CA cert, signed forwarder cert + key, and SSL password written to `.tmp/` staging directory
5. `ib_control.reload` copies staged files to Splunk's `system/local/` directory

### Health Check Endpoint

- **URL**: `GET http://127.0.0.1:9006/health`
- **Docker HEALTHCHECK**: every 10s, timeout 20s, start-period 12s
- **Checks performed** (every 30s):
  - Splunk status file (`/infoblox/var/splunk_status`)
  - `splunkd` process running on port 8089
  - TLS connectivity to each Reporting Server indexer
  - WAPI connectivity to NIOS Grid

### Health Status Messages

| Status | Message | Meaning |
|--------|---------|---------|
| 202 | `healthy` | All checks pass |
| 202 | `yet to be configured` | Waiting for initial configuration |
| 202 | `splunk is disabled` | Destination disabled by user |
| 400 | `processes are not running` | splunkd not running |
| 400 | `reporting server connection error` | Cannot reach indexer(s) |
| 400 | `grid wapi connection error` | Cannot reach NIOS Grid |
| 400 | `registration/connection error` | SSL registration failed |

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `cdc.splunkforwarderbase` | Base Docker image with Splunk UF 9.1.0, supervisord, config_writer |
| `cdc.common` | Shared Go libraries: health checking, logging, crypto, Splunk config parsing |
| `cdc.appbase` | Foundation Alpine image (inherited via splunkforwarderbase) |
| `requests` (Python) | HTTP client for host manager API calls |
| `openssl` (CLI) | CSR generation and private key encryption |

## Build & Deploy

### Build

```bash
# Build Docker image (generates unique SPLUNK_INSTANCE_GUID)
make build

# Push to registry
make push
make push-latest
```

The Makefile generates a deterministic `SPLUNK_INSTANCE_GUID` using:
```bash
uuidgen --sha1 --namespace @dns --name "ib-cdc" | tr 'a-z' 'A-Z'
```

### Deploy (docker-compose)

```yaml
services:
  reporting-out:
    image: 'infobloxcto/cdc.reporting-out:latest'
    network_mode: host  # Required: host IP registered in Grid
    volumes:
      - /infoblox/data/out/reporting:/infoblox/data/out/reporting
      - /infoblox/dev/log:/dev/log
      - /infoblox/cdc_metrics/reporting_out:/var/cache/cdc_metrics
    environment:
      - LOG_LEVEL=DEBUG
      - NODE_IP=${NODE_IP}
      - ONPREM_MONITOR_PORT=18125
      - ONPREM_HOSTMANAGER_PORT=18126
```

### Image Registry

```
infobloxcto/cdc.reporting-out:<version>
infobloxcto/cdc.reporting-out:latest
```
