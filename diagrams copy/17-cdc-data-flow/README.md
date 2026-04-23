# CDC Data Flow — Helm Chart for K8s RBAC & Grafana Dashboard

## Purpose

`cdc.data.flow` is a **Helm chart** (not an application) that provisions Kubernetes RBAC resources and a Grafana monitoring dashboard for the CDC Data Flow namespace. It creates the ServiceAccount, Roles, RoleBindings, and a GrafanaDashboard CR required by `cdc.flow.api.service` to dynamically manage StatefulSets, ConfigMaps, and Pods at runtime.

The chart does **not** deploy any application containers — it establishes the infrastructure permissions and observability layer that the Flow API Service depends on.

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Helm Chart: cdc-data-flow           │
│                                                  │
│  ┌──────────────┐  ┌────────────────────────┐   │
│  │ ServiceAccount│  │ Role: cdc-sts-manager  │   │
│  │   "ibcto"     │  │  StatefulSets (CRUD)   │   │
│  └──────┬───────┘  │  ConfigMaps (CRUD)      │   │
│         │          │  Pods (CRUD)            │   │
│         │          └────────────┬────────────┘   │
│         │                       │                │
│         │          ┌────────────┴────────────┐   │
│         │          │ Role: cdc-cm-manager     │   │
│         │          │  ConfigMaps (get/update/ │   │
│         │          │  list/watch)             │   │
│         │          └─────────────────────────┘   │
│         │                                        │
│  ┌──────┴────────────────────────────────────┐   │
│  │  GrafanaDashboard CR: cdc-data-flow       │   │
│  │  Folder: "SaaS Ecosystem"                 │   │
│  │  Datasource: Prometheus                   │   │
│  └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## Data Flow

This chart itself does not process data. It enables the following operational flow:

1. **Helm install/upgrade** renders templates with values for the target environment
2. **ServiceAccount `ibcto`** is created in the `cdc-data-flow` namespace with `imagePullSecretName` for pulling container images
3. **RBAC Roles** grant the service account permissions to manage K8s resources:
   - `cdc-sts-manager` — full CRUD on StatefulSets, ConfigMaps, and Pods (used by `flow.api.service` to create per-flow StatefulSets)
   - `cdc-cm-manager` — read/update on ConfigMaps (used to update flow configurations)
4. **GrafanaDashboard CR** is reconciled by the Grafana operator, loading the JSON dashboard into the "SaaS Ecosystem" folder
5. `cdc.flow.api.service` uses the `ibcto` service account to dynamically provision CDC flow pipelines as StatefulSets

## Key Files & Directory Structure

```
cdc.data.flow/
├── Makefile                    # Helm build, package, push, lint targets
├── Makefile.vars               # Project vars (chart name, versions, registry)
├── Jenkinsfile                 # CI/CD pipeline
├── build/
│   └── build.properties.in    # Chart file/repo property template
└── repo/
    └── cdc-data-flow/          # Helm chart root
        ├── Chart.yaml          # Chart metadata (v1.0, appVersion 1.0)
        ├── values.yaml         # Default values (namespace, SA, dashboard, alerts)
        ├── .helmignore
        ├── dashboards/
        │   └── cdc-data-flow.json   # Grafana dashboard definition (857 lines)
        └── templates/
            ├── _helpers.tpl              # Template helpers (name, namespace, labels, varTree)
            ├── sa.yaml                   # ServiceAccount (conditional on serviceAccount.enabled)
            ├── cdc-sts-manager-role.yaml # Role + RoleBinding for StatefulSet/ConfigMap/Pod CRUD
            ├── cdc-cm-update-role.yaml   # Role + RoleBinding for ConfigMap read/update
            ├── dashboard-grafana.yaml    # GrafanaDashboard CR (conditional on dashboard.enabled)
            └── rendered-dashboard.yaml   # Pre-rendered example of all templates
```

### Template Details

| Template | K8s Resource | Purpose |
|----------|-------------|---------|
| `sa.yaml` | ServiceAccount `ibcto` | Created when `serviceAccount.enabled=true`. Includes `imagePullSecrets`. |
| `cdc-sts-manager-role.yaml` | Role + RoleBinding | Grants `ibcto` SA full CRUD on `statefulsets`, `configmaps`, `pods` in the namespace. RoleBinding references namespace `cdc-flow`. |
| `cdc-cm-update-role.yaml` | Role + RoleBinding | Grants `ibcto` SA `get`, `update`, `list`, `watch` on `configmaps`. |
| `dashboard-grafana.yaml` | GrafanaDashboard CR | `integreatly.org/v1alpha1` CR pointing Prometheus datasource to the JSON dashboard. |
| `_helpers.tpl` | — | Defines `cdc-data-flow.name`, `cdc-data-flow.namespace`, `cdc-data-flow.fullname`, `cdc-data-flow.labels`, and `varTree` merge helper. |

### Grafana Dashboard Panels

The `cdc-data-flow.json` dashboard (857 lines) monitors CDC flow pods with Prometheus queries:

| Section | Panels | Key PromQL |
|---------|--------|-----------|
| **Memory & CPU Usage** | CPU Usage, Memory Usage | `container_cpu_usage_seconds_total{namespace="cdc-data-flow"}`, `container_memory_working_set_bytes` |
| **Pod Status & Restart** | Pod Restart Events, Pod Status | `kube_pod_container_status_restarts_total`, `kube_pod_status_phase` |
| **ConfigMaps & StatefulSets** | StatefulSet Ready Replicas, ConfigMaps Count | `kube_statefulset_status_replicas_ready`, `kube_configmap_info` |
| **Network Monitoring** | Network Receive/Transmit Bytes | `container_network_receive_bytes_total`, `container_network_transmit_bytes_total` |
| **Alerts** | Pod Failed, CPU Alert, Memory Alert | Alert rules with notification UIDs from `values.yaml` |

Dashboard supports template variables: `account_id`, `flow_id`, `pod_status` for filtering by specific CDC flow instances.

## Configuration

### values.yaml

```yaml
imagePullSecretName: imagepullsecret     # K8s secret for pulling images
namespace: cdc-data-flow                 # Target namespace
env: env-4                               # Environment identifier

notificationUids:                        # Grafana alert notification channels
  podFailed:
    id: d6690b9f-e56b-47bf-899a-0000
  podRestart:
    id: fdd50169-04ee-4d72-bcc0-1111
  cpuMemoryLimit:
    id: ab139c6d-d990-465e-956a-2222

serviceAccount:
  enabled: true                          # Create ServiceAccount
  name: ibcto                            # SA name used by flow.api.service

dashboard:
  enabled: true                          # Deploy GrafanaDashboard CR
  folder: "SaaS Ecosystem"              # Grafana folder name
```

### Environment Overrides

The Makefile supports rendering for specific environments via `deployment-configurations`:
- `ENV` — target environment (default: `env-4`)
- `LIFECYCLE` — deployment lifecycle (default: `dev`)
- `NAMESPACE` — K8s namespace (default: `cdc-data-flow`)

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| **Helm 3.2.4+** | Chart packaging and rendering |
| **Kubernetes 1.x** | Target cluster with RBAC enabled |
| **Grafana Operator** (`integreatly.org/v1alpha1`) | Reconciles `GrafanaDashboard` CRs |
| **Prometheus** | Datasource for dashboard metrics |
| **deployment-configurations** repo | Provides per-environment Helm value overrides |
| **cdc.flow.api.service** | The application that uses these RBAC permissions to create flow StatefulSets |

## Build & Deploy

```bash
# Lint the chart
make helm-lint

# Package the chart (creates .tgz in repo/)
make build-helm-package

# Render templates for a specific environment
make helm-yaml ENV=env-4

# Render for local development (with overrides)
make helm-yaml-local

# Push chart to S3-based Helm repo
make push-chart

# Generate build properties for CI
make build-helm-property
```

The chart is versioned using Git tags (`git describe`). The Jenkinsfile automates lint → package → push in CI.
