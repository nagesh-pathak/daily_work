# CDC Onboarding

## Purpose

CDC Onboarding (`cdc.onboarding`) is a **customer setup, testing, and data analysis toolkit** for the Cloud Data Connector (CDC) platform. It provides:

1. **Customer Data Consolidation** — Go-based tool that queries CSP APIs to fetch flows, hosts, accounts, and UPS data, then generates CSV reports for analysis
2. **Setup Guides** — Step-by-step documentation for configuring data sources (NIOS, BloxOne) and destinations (Splunk, Syslog, Reporting, Splunk Cloud, SOAR Light)
3. **QA Data Generators** — Python scripts for creating test data across data types (DNS/RPZ, DHCP, Audit Logs, Internal Notifications)
4. **Cloud-to-Cloud Flow Testing** — Go HTTP service for testing CDC flow CRUD operations
5. **Troubleshooting Resources** — Common problems, Linux tricks, and Kafka debugging guides

This repository is **not a deployed service** — it's an operational toolkit used by engineering and support teams during customer onboarding, QA testing, and issue diagnosis.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    cdc.onboarding                        │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │         deploy/customer-data/                     │   │
│  │  ┌────────────┐  ┌─────────────┐  ┌───────────┐  │   │
│  │  │  Makefile   │  │  main.go    │  │  run.sh   │  │   │
│  │  │ (curl API   │  │ (CSV report │  │ (entry    │  │   │
│  │  │  fetcher)   │  │  generator) │  │  point)   │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └───────────┘  │   │
│  │         │                │                         │   │
│  │   Fetch JSON from   Parse & generate               │   │
│  │   CSP APIs          CSV reports                    │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │         qa/script/                                │   │
│  │  ┌─────────┐  ┌──────────┐  ┌─────────────────┐  │   │
│  │  │  atc/   │  │  dhcp/   │  │  in_audit/      │  │   │
│  │  │DNS/RPZ  │  │DHCP lease│  │Internal Notif + │  │   │
│  │  │data gen │  │data gen  │  │Audit Log gen    │  │   │
│  │  └─────────┘  └──────────┘  └─────────────────┘  │   │
│  │         ▲              ▲              ▲            │   │
│  │         └──────────────┴──────────────┘            │   │
│  │                 common_utils/                      │   │
│  │          (service_utils.py, ssh_util.py)           │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │         setup/                                    │   │
│  │  Source guides: NIOS, BloxOne                     │   │
│  │  Destination guides: Splunk, Syslog, Reporting,   │   │
│  │    Splunk Cloud, SOAR Light, Kafka UI             │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         │                    │                  │
         ▼                    ▼                  ▼
┌──────────────┐   ┌───────────────┐   ┌──────────────────┐
│ CSP APIs     │   │ NIOS Grid     │   │ On-Prem Hosts    │
│ (flows,      │   │ (WAPI, DFP,   │   │ (SSH, dig, DHCP) │
│  hosts,      │   │  DHCP)        │   │                  │
│  accounts)   │   │               │   │                  │
└──────────────┘   └───────────────┘   └──────────────────┘
```

## Data Flow

### Customer Data Consolidation (`deploy/customer-data/`)

```
1. run.sh sets ENV (env-2a/stage/env-5/prod) and Bearer TOKEN
       │
       ▼
2. make consolidate → make generate-data
       │
       ├── curl GET /api/cdc-flow/v1/display/flows     → data/flows.json
       ├── curl GET /api/infra/v1/saas_hosts            → data/hosts.json
       ├── curl GET /api/upgrade_policy/v1/active_accts → data/ups_accounts.json
       └── curl GET /v2/current_user/accounts           → data/accounts.json
       │
       ▼
3. go run main.go
       │
       ├── Parse flows.json → allFlows_<timestamp>.csv
       ├── Filter SOURCE_BLOXONE → sourceB1_<timestamp>.csv
       ├── Filter DESTINATION_BLOXONE → destinationB1_<timestamp>.csv
       ├── Parse hosts.json → hostInfo_<timestamp>.csv
       └── Cross-reference hosts ↔ accounts → HostAccMap_<timestamp>.csv
```

### QA Data Generation

```
1. Configure config.ini with cluster details (CSP URL, credentials, hosts)
       │
       ▼
2. Python scripts authenticate via CSP sign-in endpoint
       │
       ▼
3. Create test resources via CSP APIs:
   ├── atc/: DFP service → Custom List → Security Policy → dig queries → cleanup
   ├── dhcp/: IP Space → Subnet → Range → DHCP leases via dras tool → cleanup
   └── in_audit/: Create/delete CSP users → generates audit log entries
```

## Key Files & Directory Structure

```
cdc.onboarding/
├── README.md                           # Main README
├── README_DEV.md                       # Developer reference
├── README_QA.md                        # QA Splunk setup guide (detailed)
├── CODEOWNERS                          # Code ownership
├── linux-tricks.md                     # Linux troubleshooting snippets
│
├── deploy/
│   ├── customer-data/                  # Customer data consolidation tool
│   │   ├── Makefile                    # API fetch targets (get-flows, get-hosts, etc.)
│   │   ├── main.go                     # CSV report generator (Go)
│   │   ├── run.sh                      # Entry point script (ENV + TOKEN)
│   │   ├── readme.md                   # Tool documentation
│   │   └── data/                       # Output directory (generated CSVs + JSON)
│   └── docker_harbor/
│       └── readme.md                   # Docker Harbor setup guide
│
├── setup/                              # Destination & source setup guides
│   ├── destination-splunk.md           # Splunk server setup (docker-compose, certs)
│   ├── destination-syslog.md           # Syslog TLS/SSL setup (rsyslog, certtool)
│   ├── destination-reporting.md        # NIOS Reporting setup (placeholder)
│   ├── destination-splunkcloud.md      # Splunk Cloud setup (placeholder)
│   ├── destination-soar-light.md       # SOAR Light setup (placeholder)
│   ├── source-nios.md                  # NIOS source setup (placeholder)
│   ├── source-bloxone.md              # BloxOne source setup (placeholder)
│   └── kafka-ui.md                     # Kafka UI access guide (teleport + port-forward)
│
├── qa/
│   └── script/
│       ├── common_utils/
│       │   ├── service_utils.py        # CSP API helpers (auth, service CRUD, host mgmt)
│       │   └── ssh_util.py             # SSH remote command execution
│       ├── atc/                         # DNS & RPZ data generator
│       │   ├── config.ini              # Cluster config (CSP URL, host, credentials)
│       │   ├── create_dns_and_rpz_data.py  # Creates DFP, custom list, security policy
│       │   ├── dns_rpz_util.py         # DFP & custom list API helpers
│       │   └── readme.md               # Usage instructions
│       ├── dhcp/                        # DHCP lease data generator
│       │   ├── config.ini              # Cluster config
│       │   ├── create_dhcp_network_range.py  # Creates IP space, subnet, range, leases
│       │   ├── dhcp_utils.py           # DHCP API helpers
│       │   ├── dras/                   # DHCP relay agent simulator tool
│       │   └── readme.md               # Usage instructions
│       └── in_audit/                    # Internal notifications & audit log generator
│           ├── config.ini              # Cluster config
│           ├── create_internal_notifications_and_audit_log.py  # Creates/deletes users
│           ├── create_user_util.py     # User management helpers
│           └── readme.md               # Usage instructions
│
├── examples/
│   └── kafka_log_generator/            # Kafka log generator utilities
│
├── test-cloud-to-cloud-flow/           # C2C flow testing service
│   ├── main.go                         # HTTP server (:7272) with CRUD handlers
│   ├── handler.go                      # Flow create/update/delete/list handlers
│   ├── utils.go                        # Utility functions
│   ├── flowRecordFile.json             # Flow record storage
│   └── test-cloud-to-cloud-flow.sh     # Test script
│
├── problems/
│   └── README.md                       # Common problems (Docker buildx, VPN, Apple Silicon)
│
├── local-apps/
│   └── tsh-install.md                  # Teleport SSH installation guide
│
└── help-docs/
    └── customer-data/                  # Additional customer data documentation
```

## Configuration

### Customer Data Tool (`deploy/customer-data/`)

#### Supported Environments

| Environment | Base URL |
|-------------|----------|
| `env-2a` | `https://env-2a.test.infoblox.com` |
| `env-5` | `https://env-5.test.infoblox.com` |
| `stage` | `https://stage.csp.infoblox.com` |
| `prod` | `https://csp.infoblox.com` |

#### Authentication

The tool uses **Bearer token** authentication. Set the token in `run.sh`:

```bash
export ENV="env-2a"
export TOKEN="<your-auth-token>"
make consolidate ENV=$ENV TOKEN=$TOKEN
```

#### CSP API Endpoints Queried

| Makefile Target | API Endpoint | Output |
|-----------------|-------------|--------|
| `get-flows` | `GET /api/cdc-flow/v1/display/flows` | `data/flows.json` |
| `get-hosts` | `GET /api/infra/v1/saas_hosts?_filter=configs.serviceType=="cdc"` | `data/hosts.json` |
| `get-ups-accounts` | `GET /api/upgrade_policy/v1/active_accounts` | `data/ups_accounts.json` |
| `get-accounts` | `GET /v2/current_user/accounts` | `data/accounts.json` |

#### CSV Output Files

| File | Content |
|------|---------|
| `allFlows_<ts>.csv` | All flows with host assignments |
| `sourceB1_<ts>.csv` | Flows with BloxOne source type |
| `destinationB1_<ts>.csv` | Flows with BloxOne destination type |
| `hostInfo_<ts>.csv` | Host details (ID, account, IP, version, last seen) |
| `HostAccMap_<ts>.csv` | Host-to-account mapping with flow details |

### QA Scripts Configuration (`qa/script/`)

Each QA module uses a `config.ini` file with common settings:

```ini
[DEFAULT]
csp = env-2a.test.infoblox.com      # CSP cluster URL
cspuser = atlasautomation@infoblox.site  # CSP username
csppswd = <password>                  # CSP password
onpremhost = 172.28.7.40             # On-prem host IP
pem_file = /root/ib-shared.pem       # SSH key file
sshonprem = 172.28.7.40              # SSH host
client_user = ubuntu                  # SSH username
```

#### Authentication Flow (QA Scripts)

1. Python scripts call `POST /v2/session/users/sign_in` with email + password
2. Response JWT is extracted and used as `Bearer` token for subsequent API calls
3. All API operations use `service_utils.py` helper functions

### QA Data Generators

| Module | Data Type Generated | Method |
|--------|-------------------|--------|
| `atc/` | DNS query/response logs, RPZ threat feed hits | Creates DFP service → custom list → security policy → `dig` queries via SSH |
| `dhcp/` | DHCP lease logs | Creates IP space → subnet → range → leases via `dras` tool |
| `in_audit/` | Internal notifications, audit logs | Create/delete CSP users (generates audit events) |

### Cloud-to-Cloud Flow Test Service

A standalone Go HTTP server on port **7272** for testing CDC flow operations:

| Method | Endpoint | Action |
|--------|----------|--------|
| `POST` | `/testctocflow` | Create a new flow |
| `PUT` | `/testctocflow` | Update an existing flow |
| `GET` | `/testctocflow` | List all flows |
| `DELETE` | `/testctocflow` | Delete a flow |

## Dependencies

| Dependency | Purpose |
|------------|---------|
| **Go** | Customer data tool (`main.go`), C2C flow test service |
| **Python 3** | QA data generation scripts |
| **curl** | API data fetching (Makefile targets) |
| **requests** (Python) | HTTP client for CSP API calls |
| **configparser** (Python) | INI config file parsing |
| **GNU Make** | Build orchestration for data consolidation |
| **SSH / pem keys** | Remote command execution on on-prem hosts |
| **dras** | DHCP relay agent simulator for lease generation |
| **inotifywait** | Not used here (used in splunkforwarderbase) |
| **gorilla/mux** | HTTP router for C2C test service |
| **bwmarrin/snowflake** | Unique ID generation for test flows |

## Build & Deploy

### Customer Data Consolidation

```bash
cd deploy/customer-data/

# Edit run.sh with your environment and token
vim run.sh

# Run the consolidation
./run.sh

# Or run individual steps:
make get-flows ENV=stage TOKEN=<token>
make get-hosts ENV=stage TOKEN=<token>
make generate-data ENV=stage TOKEN=<token>
go run main.go
```

### QA Data Generation

```bash
cd qa/script/atc/

# Edit config.ini with cluster details
vim config.ini

# Run DNS/RPZ data generation
python create_dns_and_rpz_data.py
```

```bash
cd qa/script/dhcp/

# Edit config.ini, set dras paths
vim config.ini
export CDC_DRAS=<path-to-dras>
export CP_CDC_DRAS=<path-for-dras-on-client>

# Run DHCP data generation
python create_dhcp_network_range.py
```

```bash
cd qa/script/in_audit/

# Edit config.ini
vim config.ini

# Run audit/notification data generation
python create_internal_notifications_and_audit_log.py
```

### Cloud-to-Cloud Flow Test Service

```bash
cd test-cloud-to-cloud-flow/

# Run the test service
go run main.go handler.go utils.go
# Service starts on :7272
```

### Splunk Destination Setup (from README_QA.md)

```bash
# Quick Splunk server with Docker
docker run -d -p 8000:8000 -p 9997:9997 -p 8089:8089 \
  -e "SPLUNK_START_ARGS=--accept-license" \
  -e "SPLUNK_PASSWORD=Splunk123" \
  --name splunk splunk/splunk:latest
```

For TLS-enabled Splunk, see `README_QA.md` for certificate generation with `openssl` and configuration of `inputs.conf`/`server.conf`.
