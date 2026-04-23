# CDC CRDs — Kubernetes Custom Resource Definitions for Cloud Data Sources

## Purpose

CDC CRDs defines **Kubernetes Custom Resource Definitions** (CRDs) for the CDC data flow ecosystem. It provides the `CloudDataSource` CRD under the API group `flow.cdc.infoblox.com/v1`, which represents available data source types (e.g., BloxOne DNS logs, DHCP leases, audit logs) that can be used when creating CDC flows.

Key capabilities:
- **CloudDataSource CRD**: Declarative Kubernetes resource describing available data sources and their Kafka topic configurations
- **Embedded CRD manifest**: The YAML CRD spec is embedded in Go via `//go:embed`, enabling other services to import it as a Go module dependency
- **Controller-runtime operator**: Kubebuilder-scaffolded manager with health/ready probes and leader election
- **Shared type definitions**: Go structs with validation markers used by `cdc.flow.api.service` and `cdc.kafka.flow.processor`

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                                │
│                                                                     │
│  ┌─────────────────────────────────┐                                │
│  │   CloudDataSource CRD           │                                │
│  │   (flow.cdc.infoblox.com/v1)    │                                │
│  │                                 │                                │
│  │   Defines: data source types,   │                                │
│  │   Kafka topics, broker addrs    │                                │
│  └──────────┬──────────────────────┘                                │
│             │                                                       │
│    ┌────────┼────────────────────────────┐                          │
│    │        │                            │                          │
│    ▼        ▼                            ▼                          │
│  Operator  cdc.flow.api.service     cdc.kafka.flow.processor        │
│  Manager   (reads CDS to validate   (reads CDS to resolve          │
│  (:8080    flow source configs)      Kafka topic/broker info)       │
│   :8081)                                                            │
│                                                                     │
│  ┌─────────────────────────────────────────────────┐                │
│  │          CloudDataSource Instances               │                │
│  │                                                  │                │
│  │  cds/td-query-resp-log                           │                │
│  │    source_type: SOURCE_BLOXONE                   │                │
│  │    sources: [{kind: kafka, topics, brokers}]     │                │
│  │                                                  │                │
│  │  cds/ddi-dhcp-lease-log                          │                │
│  │    source_type: SOURCE_NIOS                      │                │
│  │    sources: []  (NIOS doesn't use Kafka sources) │                │
│  └─────────────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────────────┘
```

### How Other Services Use the CRD

**cdc.flow.api.service**:
- Imports `github.com/Infoblox-CTO/cdc.crds/api/v1` as a Go module
- Lists `CloudDataSource` resources to discover available data types
- Validates flow creation requests against CDS definitions
- Uses `SourceSpec` to determine Kafka topics and brokers for new flows

**cdc.kafka.flow.processor**:
- Imports the same Go types to resolve Kafka topic and broker configurations
- Reads `CloudDataSource` instances to know where to consume/produce events

**Embedded CRD manifest**:
- `config/config.go` uses `//go:embed` to embed the YAML CRD into a Go string variable (`config.Crd`)
- `api/v1/consts.go` re-exports this as `v1.Crd`
- Consumers can apply the CRD manifest programmatically without needing the YAML file

## Data Flow

### CRD Schema: CloudDataSourceSpec

```yaml
apiVersion: flow.cdc.infoblox.com/v1
kind: CloudDataSource
metadata:
  name: td-query-resp-log
spec:
  id: "TD_QUERY_RESP_LOG"              # Unique identifier (uppercase, alphanumeric + underscore)
  title: "DNS Query Response Logs"      # Human-readable name for UI dropdowns
  description: "Threat Defense DNS..."  # Tooltip description
  source_type: "SOURCE_BLOXONE"         # Enum: SOURCE_BLOXONE or SOURCE_NIOS
  source_subtypes:                      # Optional list of sub-data-types
    - "DNS_QUERY"
  source_fields:                        # Optional configurable fields for UI
    - id: "log_level"
      name: "Log Level"
      type: Select                      # Select, Range, or Text
      required: true
      default_value: "info"
      options:
        - value: "info"
          label: "Info"
        - value: "debug"
          label: "Debug"
  sources:                              # Kafka source configurations
    - kind: kafka                       # Only "kafka" currently supported
      name: "primary"                   # Human-readable source name
      metadata:                         # Kafka connection details
        broker_addresses: "broker1:9092,broker2:9092"
        topics: "td_query_resp_log"
status:
  value: "Synced"                       # FlowAPI sync status
  messages: []                          # Error messages (empty when healthy)
```

### Spec Fields Reference

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `id` | string | Yes | MinLength=1, Pattern=`^([0-9A-Z_])*?$` | Unique CDS identifier |
| `title` | string | Yes | MinLength=1 | Short description for UI dropdowns |
| `description` | string | No | — | Tooltip text |
| `source_type` | string | Yes | Enum: `SOURCE_BLOXONE`, `SOURCE_NIOS` | Data source platform |
| `source_subtypes` | []string | No | — | Sub-data-type list |
| `source_fields` | []SourceField | No | — | Configurable UI fields (Select/Range/Text) |
| `sources` | []SourceSpec | No | — | Kafka source configs (BloxOne only) |

### SourceSpec Sub-Schema

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `kind` | string | Yes | Enum: `kafka` | Stream provider technology |
| `name` | string | Yes | MinLength=1 | Human-readable source name |
| `metadata` | map[string]string | Yes | — | Key-value config (e.g., `broker_addresses`, `topics`) |

### SourceField Sub-Schema

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique field identifier |
| `name` | string | Human-readable field name |
| `type` | SourceFieldType | `Select`, `Range`, or `Text` |
| `required` | bool | Whether field is mandatory |
| `default_value` | string | Default value |
| `editable` | bool | Whether field is editable |
| `options` | []SelectOption | For Select type: `{value, label}` pairs |
| `range` | NumberRange | For Range type: `{min, max}` |
| `validation` | Validation | For Text type: `{pattern, message}` regex validation |

### Status Sub-Resource

```yaml
status:
  value: "Synced"     # or "Error", "Pending"
  messages:            # Error details when sync fails
    - "Failed to connect to broker broker1:9092"
```

The status shows whether the CDS has been successfully synced with the FlowAPI service. The `+kubebuilder:subresource:status` marker enables independent status updates.

### Printer Columns

```
$ kubectl get cds
NAME                  STATUS   AGE
td-query-resp-log     Synced   5d
ddi-dhcp-lease-log    Synced   5d
```

Short name: `cds` (via `+kubebuilder:resource:shortName=cds`)

## Key Files & Directory Structure

```
cdc.crds/
├── main.go                            # Operator entry point (controller-runtime manager)
├── go.mod                             # Go module: github.com/Infoblox-CTO/cdc.crds
├── api/v1/
│   ├── clouddatasource_types.go       # CloudDataSource CRD types with kubebuilder markers
│   │                                  #   CloudDataSourceSpec, SourceSpec, SourceField,
│   │                                  #   SelectOption, NumberRange, Validation,
│   │                                  #   CloudDataSourceStatus
│   ├── groupversion_info.go           # Group: flow.cdc.infoblox.com, Version: v1
│   ├── consts.go                      # Exports embedded CRD YAML as v1.Crd string
│   └── zz_generated.deepcopy.go       # Auto-generated DeepCopy methods
├── config/
│   ├── config.go                      # //go:embed of CRD YAML manifest
│   ├── crd/
│   │   ├── bases/
│   │   │   └── flow.cdc.infoblox.com_clouddatasources.yaml  # Generated CRD YAML
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── default/                       # Default kustomize overlay
│   ├── manager/                       # Controller manager deployment
│   ├── rbac/                          # RBAC for controller
│   ├── prometheus/                    # Prometheus scraping config
│   └── samples/
│       └── flow_v1_clouddatasource.yaml  # Sample CDS resource
├── helm/cdc-crds/
│   ├── Chart.yaml                     # Helm chart: cdc-crds v0.1.0
│   ├── values.yaml                    # Helm values
│   └── templates/
│       ├── flow.cdc.infoblox.com_clouddatasources.yaml  # CRD template
│       └── _helpers.tpl
├── hack/
│   └── boilerplate.go.txt             # License header for generated code
├── Dockerfile                         # Multi-stage build
├── Makefile                           # Build targets (manifests, generate, build, deploy)
└── PROJECT                            # Kubebuilder project metadata
```

## Configuration

### Controller Manager Flags
| Flag | Default | Description |
|------|---------|-------------|
| `--metrics-bind-address` | `:8080` | Prometheus metrics endpoint |
| `--health-probe-bind-address` | `:8081` | Health/readiness probe endpoint |
| `--leader-elect` | `false` | Enable leader election for HA |

### Leader Election
- **ID**: `22623631.cdc.infoblox.com`
- Ensures only one active controller manager when running multiple replicas
- Uses Kubernetes Lease resource for leader coordination

### Kustomize Overlays
- `config/default/` — Full deployment (CRD + operator + RBAC + metrics)
- `config/crd/` — CRD-only installation
- `config/manager/` — Controller manager deployment
- `config/rbac/` — ServiceAccount, ClusterRole, ClusterRoleBinding
- `config/prometheus/` — Prometheus ServiceMonitor

## Dependencies

### Go Dependencies
- `sigs.k8s.io/controller-runtime` v0.14.1 — Controller framework (manager, reconciler, healthz)
- `k8s.io/apimachinery` v0.26.0 — Kubernetes API types (ObjectMeta, TypeMeta)
- `k8s.io/client-go` v0.26.0 — Kubernetes API client, auth plugins

### Build Dependencies
- **Kubebuilder** — Project scaffolding and code generation
- **controller-gen** — CRD manifest + DeepCopy generation from Go markers
- **kustomize** — Kubernetes manifest composition

### CDC Ecosystem Consumers
- `github.com/Infoblox-CTO/cdc.crds/api/v1` imported by:
  - **cdc.flow.api.service** — Reads CDS resources for flow validation
  - **cdc.kafka.flow.processor** — Resolves Kafka topics/brokers from CDS
- `v1.Crd` string used to programmatically apply the CRD manifest

## Build & Deploy

### Make Targets
```bash
make manifests      # Generate CRD YAML + RBAC from kubebuilder markers
make generate       # Generate DeepCopy methods
make fmt            # Format Go code
make vet            # Run Go vet
make test           # Run tests with envtest (K8s 1.26.0)
make build          # Build controller binary
make docker-build   # Build Docker image
make docker-push    # Push Docker image
make install        # Install CRD into cluster (kustomize)
make uninstall      # Remove CRD from cluster
make deploy         # Deploy controller to cluster
make undeploy       # Remove controller from cluster
```

### Helm Deployment
```bash
# Install CRD only (most common — other services import Go types directly)
helm install cdc-crds ./helm/cdc-crds

# The Helm chart installs the CRD YAML into the cluster
# The CRD definition is copied from config/crd/bases/ during `make manifests`
```

### Endpoints
| Endpoint | Port | Description |
|----------|------|-------------|
| `/healthz` | 8081 | Health check (ping) |
| `/readyz` | 8081 | Readiness probe (ping) |
| `/metrics` | 8080 | Prometheus metrics |

### Workflow: Adding a New Data Source

1. Define a new `CloudDataSource` YAML manifest with the data type ID, title, source type, and Kafka sources
2. Apply to the cluster: `kubectl apply -f my-new-datasource.yaml`
3. Verify: `kubectl get cds` — should show `Synced` status
4. `cdc.flow.api.service` automatically discovers the new data source for flow creation
5. Users can now create flows with the new data type via the CDC API
