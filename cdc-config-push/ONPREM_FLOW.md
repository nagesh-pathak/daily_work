# Onprem Config Push — Detailed Flow

This document is the deep dive for the onprem path. For the high‑level
picture see [README.md](./README.md) and the
[onprem-config-push.svg](./onprem-config-push.svg) diagram.

## Components in the path

```
                        ┌──────────────────────────┐
  user / UI / API ─────▶│        cdc.api           │
                        │ (REST + gRPC, owns DB)   │
                        └─────┬─────────────┬──────┘
                              │             │
              INSERT cdc_config│             │PubSub/Kafka publish
                              ▼             ▼
                  ┌────────────────┐   topic: atlas.pubsub.publish.<container>
                  │  Postgres      │             │
                  │  cdc_config    │             │
                  └────────────────┘             ▼
                                       ┌────────────────────────────┐
                                       │   atlas.config.manager     │
                                       │   (cloud, gRPC :8090)      │
                                       │  · Kafka/PubSub consumer   │
                                       │  · per-ophid notif channel │
                                       │  · Subscribe RPC stream    │
                                       │  · UPS (maintenance win.)  │
                                       │  · S3 payload cache        │
                                       └────────┬───────────────────┘
                                                │ gRPC stream over TLS (WAN)
                                                │ ophidauth middleware
                                                ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │                      ONPREM APPLIANCE (ophid = X)                │
   │                                                                  │
   │  ┌───────────────────────────────┐                               │
   │  │ atlas.onprem.config.service   │                               │
   │  │  · Subscribe() client stream  │                               │
   │  │  · Listen() notif loop        │                               │
   │  │  · FetchConfig() fragmented   │                               │
   │  │  · ApplyConfig() (ver check)  │                               │
   │  │  · SendStatus() callback      │                               │
   │  │  · Reconcile() every 15 min   │                               │
   │  └───────┬──────────────┬────────┘                               │
   │          │              │                                        │
   │   docker.sock      kube apiserver                                │
   │          │              │                                        │
   │  ┌───────▼──────────────▼────────┐  ┌─────────────────────────┐  │
   │  │   cdc.flume / grpc_in /       │  │ atlas.onprem.health.    │  │
   │  │   http_out / siem_out / ...   │  │ reporter (independent)  │  │
   │  └───────────────────────────────┘  └─────────────────────────┘  │
   │  config file: /opt/<name>/conf/config.json                       │
   │  version  file: /infoblox/cdc/<name>/.version                    │
   └──────────────────────────────────────────────────────────────────┘
```

## End‑to‑end sequence

1. **API call**
   - `POST /cdc/v1/config/{container_name}` with body
     `{"ophid": "...", "config": {...}}`.
   - Handled by `CdcServer.CreateConfig` —
     `cdc.api/pkg/svc/api/zserver.go` (~L42–L130).

2. **Validation + dedup**
   - `IsContainerValid()` checks the name is in the allowlist
     (`dns_in | rpz_in | ipmeta_in | grpc_in | grpc_out | siem_out |
     splunk_out | splunkcloud_out | reporting_out | http_out | flume |
     soar_light`).
   - For `flume` only, `GenerateFlumeConfig()` aggregates all
     source/destination configs of the same `ophid` into one composite
     payload.
   - Reads the latest row for `(ophid, container_name)`; if the JSON is
     identical → returns **HTTP 409** and writes nothing.

3. **DB insert (the row you see in pgAdmin)**
   - `apiPb.DefaultCreateConfig(ctx, payload, s.db)` — GORM `INSERT`.
   - The Postgres trigger `cdc_config_version` fires `set_version()`
     which does `SELECT COALESCE(MAX(version),0)+1 FROM cdc_config WHERE
     ophid=NEW.ophid AND container_name=NEW.container_name` and writes
     it into the new row. This is why versions monotonically grow per
     `(ophid, container_name)` even with concurrent inserts (within the
     limits of the unique constraint).
   - Defaults: `message='Configuration Ready'`, `status_code=99`.

4. **PubSub notification**
   - If `atlas.pubsub.enable=true`, `SendPubSubNotification` publishes
     `PubSubConfigObject{ophid, version, app_name}` to
     `atlas.pubsub.publish.<container_name>` (one topic per container
     family).

5. **Manager consumes**
   - `atlas.config.manager/pkg/svc/pubsub.go::handleConfigUpdateNotification`
     (or `kafkaconsumer.go::sendNotification`) receives the message.
   - Looks up `onpremNotificationCh[ophid]` (in‑memory `sync.Map`,
     populated when a Subscribe stream opens).
   - **If the OPHID has an active stream on this pod**, push the
     `SubscribeResponse{Notification}` into the channel
     (buffer size 1).
   - **Else** the message is ACKed and dropped — the next 15‑min
     reconcile from onprem will recover it. This is logged as
     `... isn't served by this Config Manager`.

6. **Manager → Onprem stream**
   - `atlas.config.manager/pkg/svc/zserver.go::Subscribe()` is the
     server‑streaming RPC. It pulls from the channel and writes
     `SubscribeResponse` frames on the open gRPC stream. KeepAlive
     frames every ~30 s.

7. **Onprem receives**
   - `atlas.onprem.config.service/configservice/configservice.go::Subscribe`
     (~L73–L130) is the client side. It validates KeepAlive and forwards
     real notifications to a Go channel consumed by `Listen()`.
   - Reconnect on 4 consecutive missed keepalives (exponential backoff,
     base 1 s, ×1.5, max 60 s).

8. **Fetch full config**
   - `Listen()` calls `FetchConfig()` →
     `configservice.go::GetConfig` (~L166) which makes a
     `GetConfigRequest{ophid, app, version}` to the manager.
   - Manager streams the payload back as fragments (4 MB chunks, each
     with SHA‑1). Onprem reassembles and validates.

9. **Version check (the dedup that produces "Did not apply…")**
   - In `cmd/server/internal/configclient/configclient.go` (~L234‑L268):
     ```go
     currentVersion := convertToVersion(readFile(app.ConfigVersionFilePath))
     newVersion     := convertToVersion(desiredConfig.Version)
     if newVersion.GreaterThan(currentVersion) {
         status, err := c.ApplyConfig(...)
     } else {
         msg := fmt.Sprintf("Did not apply config as %s container has same/newer version %s",
                            app.Name, currentVersion)
         c.SendStatus(SUCCESS, msg)   // status_code=0 written back to cdc_config
     }
     ```
   - `hashicorp/go-version` SemVer comparison. Equal counts as **not
     greater** → skipped.

10. **Apply**
    - Writes JSON to `app.ConfigFilePath` (e.g.
      `/opt/flume/conf/flume.json`).
    - If `ReloadPolicy="script"` runs `app.ReloadScript`; if
      `"restart"`, restarts the container via Docker API or K8s.
    - On success, overwrites `app.ConfigVersionFilePath` with the new
      version string. **This file is the dedup ground truth on the next
      push.**

11. **Status callback**
    - `SendStatus(ophid, container_name, version, message, status_code)`
      goes through the manager which proxies to
      `cdc.api.UpdateConfigStatus` →
      `UPDATE cdc_config SET message=?, status_code=? WHERE
      ophid=? AND version=? AND container_name=?`.

12. **Health reporter (parallel)**
    - `atlas.onprem.health.reporter` keeps reporting container state /
      heartbeats to the cloud Health Collector independently of the
      config push.

## File reference index

| Concern | Repo | Path | Function |
|---------|------|------|----------|
| Schema | `cdc.api` | `db/migrations/1_cdc_schema.up.sql` | `cdc_config` table + `set_version` trigger |
| API: create | `cdc.api` | `pkg/svc/api/zserver.go` (~L42) | `CreateConfig` |
| API: get | `cdc.api` | `pkg/svc/api/zserver.go` (~L172) | `GetConfig` |
| API: update status | `cdc.api` | `pkg/svc/api/zserver.go` (~L236) | `UpdateConfigStatus` |
| API: delete | `cdc.api` | `pkg/svc/api/zserver.go` (~L359) | `DeleteConfig` (writes `{"delete":"true"}`) |
| PubSub publish | `cdc.api` | `pkg/svc/api/zserver.go` (~L337) | `SendPubSubNotification` |
| Kafka consume | `atlas.config.manager` | `pkg/svc/kafkaconsumer.go` (~L67) | `sendNotification` |
| PubSub consume | `atlas.config.manager` | `pkg/svc/pubsub.go` (~L221) | `handleConfigUpdateNotification` |
| Subscribe RPC server | `atlas.config.manager` | `pkg/svc/zserver.go` (~L194) | `Subscribe` |
| UPS check | `atlas.config.manager` | `ups/ups.go` | `GetMaintenanceWindowInfo` |
| S3 cache | `atlas.config.manager` | `s3api/s3api.go` |  |
| Subscribe RPC client | `atlas.onprem.config.service` | `configservice/configservice.go` (~L73) | `Subscribe` |
| GetConfig fragments | `atlas.onprem.config.service` | `configservice/configservice.go` (~L166) | `GetConfig` |
| Listen + Apply loop | `atlas.onprem.config.service` | `cmd/server/internal/configclient/configclient.go` (~L82, L234) | `Listen`, `ApplyConfig` |
| Reconcile (15 min) | `atlas.onprem.config.service` | `cmd/server/internal/configclient/configclient.go` (~L110) | `Reconcile` |
| KeepAlive monitor | `atlas.onprem.config.service` | `configservice/configservice.go` (~L131) | `MonitorKeepAlive` |

## Status code reference

| Code | Source | Meaning |
|------|--------|---------|
| `99` | DB default on insert | Manager has not yet processed / acked. |
| `0`  | onprem `SendStatus(SUCCESS)` | Either applied OK or skipped because local version ≥ remote. Disambiguate via `message`. |
| `98` | `cdc.api.DeleteConfig` | Tombstone insert with `{"delete":"true"}`. The onprem side then reports `Delete Initiated` / progress. |
| Non‑zero failures | onprem | `GENERAL_FAILURE`, `HASH_FAILURE` (fragment SHA mismatch), `VALIDATION_FAILURE`, `COPY_FAILURE`, `RELOAD_FAILURE`. The exact integer is defined in the `StatusCode` enum in `atlas.config.manager` proto. |

## Container reload semantics

`ReloadPolicy` is part of the per‑app metadata that
`atlas.onprem.config.service` fetches via `GetConfigMap` from the
manager:

- `script` — write file, exec script. **Container does not restart.**
  Faster, but app must hot‑reload.
- `restart` — write file, then `docker restart` (or K8s pod recreate).
  Slower, and a transient health blip is expected.

This is why apply latency varies from ~1 s (script reload) to 30 s+
(container restart with image pull / readiness probes).
