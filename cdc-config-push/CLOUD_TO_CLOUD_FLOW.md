# Cloud‑to‑Cloud Config Push

For destinations and sources that live entirely inside the BloxOne CSP
cluster (no customer appliance) the path is shorter. The same
`cdc_config` table is used; what changes is the *consumer*.

## What counts as cloud‑to‑cloud

Looking at `cdc.api/pkg/svc/common/common.go`:

```go
SrcContainer  = []string{DnsIn, IpmetaIn, RpzIn, GrpcIn}
DestContainer = []string{GrpcOut, SiemOut, SplunkOut, SplunkCloudOut,
                         ReportingOut, SoarLight, HttpOut}
```

In practice the cloud‑to‑cloud (C2C) deployments are:

| `container_name` | C2C? | Where it runs in C2C |
|------------------|------|----------------------|
| `splunkcloud_out` | yes (always) | CSP cluster, sends to Splunk Cloud |
| `http_out`        | yes (when target is a SaaS endpoint) | CSP cluster |
| `siem_out`        | sometimes  | CSP cluster when SIEM is SaaS |
| `grpc_in`         | yes (BloxOne cloud source) | CSP cluster, ingest from BloxOne |
| `flume`           | rarely C2C | Mostly the onprem aggregator |
| `dns_in`, `rpz_in`, `ipmeta_in` | no | NIOS sources, always onprem |

The `ophid` column is still populated (it identifies the *tenant* /
deployment scope, not necessarily a physical appliance), and the same
`(ophid, container_name)` history applies.

See [cloud-to-cloud-config-push.svg](./cloud-to-cloud-config-push.svg).

## Sequence

```
┌────────┐  POST /cdc/v1/config/splunkcloud_out
│  user  │ ─────────────────────────────────────▶ ┌──────────────┐
└────────┘                                        │   cdc.api    │
                                                  └─┬────────────┘
                          INSERT (trigger ver+1)    │
                                                    ▼
                                           ┌────────────────┐
                                           │ cdc_config (PG)│
                                           └────────────────┘
                                                    │
                                  PubSub publish    │
                                  topic = atlas.pubsub.publish.splunkcloud_out
                                                    ▼
                                       ┌────────────────────────────┐
                                       │  atlas.config.manager OR    │
                                       │  the cloud CDC consumer     │
                                       │  (K8s Deployment in CSP)    │
                                       └─┬───────────────────────────┘
                                         │  GET /cdc/v1/config/<container>/<ophid>/latest
                                         ▼
                                       ┌────────────────────────────┐
                                       │ Cloud-hosted CDC container │
                                       │ (cdc.splunk-out / .http-out│
                                       │  / .siem-out / .grpc-in)   │
                                       └─┬───────────────────────────┘
                                         │  POST /cdc/v1/status/<container>
                                         ▼
                                       ┌────────────────┐
                                       │   cdc.api      │  UPDATE message + status_code
                                       └────────────────┘
```

## Differences vs onprem

| Aspect | Onprem | Cloud‑to‑cloud |
|--------|--------|----------------|
| Transport from manager to consumer | gRPC `Subscribe` stream over WAN, TLS, ophidauth | In‑cluster gRPC or HTTP `GET /config/.../latest` |
| Local version file | `/infoblox/cdc/<name>/.version` on appliance | In‑memory or ConfigMap annotation in the K8s Deployment |
| Maintenance window check (UPS) | Yes | No (cloud changes don't need a customer MW) |
| Reload policy | `script` or `restart` of host container | K8s rolling update of the Deployment |
| Failure dominantly caused by | WAN, dedup on appliance, manager pod sharding | PubSub/Kafka delivery, consumer pod health, tenant `ophid` mismatch |
| Reconcile loop | Every 15 min from `atlas.onprem.config.service` | Driven by the consumer's own readiness/restart |
| Status callback | Through manager → `cdc.api` | Direct REST/gRPC → `cdc.api` |

## Why a C2C config can sit at `status_code=99`

1. **PubSub topic misconfigured** — `atlas.pubsub.publish.<container>`
   not set or the consumer is subscribed to a different topic.
2. **Consumer pod down** — the cloud CDC container is in `CrashLoopBackOff`
   or unschedulable; nobody is calling `GET /config`.
3. **Wrong tenant `ophid`** — the consumer filters by tenant and the row
   was written with a different one (frequent after tenant migrations).
4. **DB race** — read‑your‑own‑writes on Postgres replica with stale
   read replica. Force the consumer to read from primary or refresh.
5. **Identical config** — consumer fetched, computed hash, decided no
   reload was needed. Some cloud consumers will still call
   `UpdateConfigStatus` with `status_code=0` and a `Did not apply…`
   message; check the row's `message` column.

## Repo references

| Container | Repo |
|-----------|------|
| `splunkcloud_out` | (cloud build of `cdc.splunk-out` configured for Splunk Cloud) |
| `http_out` | `cdc.http-out` |
| `siem_out` | `cdc.siem-out` |
| `grpc_in` | `cdc.grpc-in` |
| `flume` | `cdc.flume` |
