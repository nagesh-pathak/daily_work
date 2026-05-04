# Debugging "DB has the latest version but the onprem container did not pick it up"

Use this checklist top‑to‑bottom. Each step tells you which side to look
on and what to grep / query.

## Step 0 — Read the row first

```sql
SELECT id, ophid, container_name, version, status_code, message,
       created_at, updated_at
FROM   cdc_config
WHERE  ophid = '<OPHID>'
  AND  container_name = '<NAME>'
ORDER  BY version DESC
LIMIT  5;
```

Interpretation:

| Latest row | Meaning | Go to |
|------------|---------|-------|
| `status_code = 99`, `message = 'Configuration Ready'` | Manager has not yet acked. Either notification not delivered, ophid not connected, or apply still in progress. | Step 1 |
| `status_code = 0`, message starts with `Did not apply config as ...` | **Onprem received it and deduped.** Local on‑disk version ≥ pushed version. | Step 5 |
| `status_code = 0`, message starts with `[CONFIG SUCCESS]` | Applied. The "stale" perception is wrong; check the data path / container logs instead. | done |
| `status_code = 98`, message `Delete Initiated` | Tombstone — a delete was requested. | Step 6 |
| Non‑zero / non‑98 | Apply failure (HASH/VALIDATION/COPY/RELOAD). | Step 7 |

## Step 1 — Did `cdc.api` publish the notification?

`cdc.api` logs (around `CreateConfig` in
`pkg/svc/api/zserver.go`):

```
[ophid:<NAME>] Received POST request to create new configurations
[ophid:<NAME>] Creating configuration entry in cdc_config table
```

Then in `SendPubSubNotification`:

```
Publishing pubsub notification on topic atlas.pubsub.publish.<container>
```

If `atlas.pubsub.enable=false` in the deployed config, **no
notification is sent at all** and onprem will only catch up via the
15‑min reconcile loop. Verify:

```bash
kubectl -n <ns> get cm cdc-api-config -o yaml | grep -i pubsub
```

## Step 2 — Did `atlas.config.manager` consume it?

Manager logs (Kafka or PubSub consumer):

```
Received config update notification ophid=<X> app=<NAME> version=<V>
```

Then routing:

- `served by this Config Manager` → good, it has the stream.
- `isn't served by this Config Manager` → notification dropped on
  *this* pod. Either another replica has the stream, or no replica
  does. See Step 3.

For multi‑replica clusters check **all** pods:

```bash
kubectl -n <ns> logs -l app=atlas-config-manager --tail=2000 \
  | grep -E "ophid=<X>|isn't served"
```

## Step 3 — Is the onprem appliance currently connected?

Manager log on stream open:

```
Got a connection from ophid <X>
```

And on close:

```
Subscribe stream closed for ophid <X> err=...
```

If you cannot find a recent open log, the `Subscribe` stream is down.
On the appliance check `atlas.onprem.config.service`:

```
Subscribed to config manager for ophid <X>
Missed 4 keep alives, reconnecting
```

Common causes: outbound TLS blocked, token/cert expired, DNS broken to
the manager endpoint.

## Step 4 — Was UPS (maintenance window) blocking?

Manager logs around `ups.GetMaintenanceWindowInfo`:

```
Maintenance window check: ophid=<X> in_window=false reason=...
```

If `in_window=false`, the manager will hold the push. Either wait for
the window to open or override per the runbook for `atlas.config.manager`.

## Step 5 — `Did not apply config as ... has same/newer version`

This is the **most common cause** of "DB has new version but nothing
changed onprem". The push *did* arrive. The onprem service compared:

```
currentVersion = read("/infoblox/cdc/<name>/.version")     # e.g. "14"
newVersion     = received                                  # e.g. "14"
if newVersion > currentVersion: apply
else: SendStatus(SUCCESS, "Did not apply config as ... has same/newer version")
```

Diagnose on the appliance:

```bash
ssh <appliance>
cat /infoblox/cdc/<name>/.version           # what onprem thinks is applied
docker exec <name> cat /opt/<name>/conf/<name>.json | jq .   # what is actually loaded
```

Then compare with the DB:

```sql
SELECT version, config FROM cdc_config
WHERE ophid='<X>' AND container_name='<NAME>'
ORDER BY version DESC LIMIT 1;
```

Resolution options:

- **Force re‑apply**: bump the version artificially by submitting a
  trivial change (e.g. add then revert a benign field) so a new row
  with `version+1` is generated. The version trigger guarantees
  monotonic increase.
- **Reset local version file** (only if you own the appliance):
  truncate or remove `/infoblox/cdc/<name>/.version`, then trigger a
  reconcile by restarting `atlas.onprem.config.service`. The next push
  will see `currentVersion=0` and apply.
- **Confirm versions match by accident**: if a previous push already
  delivered the same JSON content under a higher version, the user's
  "new" config might not actually differ — check with `diff` of the
  two JSON payloads.

## Step 6 — Delete row stuck

Row is `status_code=98, message='Delete Initiated'`. The onprem service
should:
1. Stop / remove the container.
2. Clear `/infoblox/cdc/<name>/.version`.
3. Send `SendStatus(SUCCESS, "[CONFIG SUCCESS]: ... deleted")`.

If it never moves past `Delete Initiated`, check service logs for
`docker rm` errors or K8s pod stuck terminating.

## Step 7 — Apply failure

`status_code` is non‑zero/non‑98 and `message` carries one of:

- `HASH_FAILURE` → SHA‑1 mismatch on a fragment during `GetConfig`.
  Usually transient; reconcile fixes it. If persistent, the manager's
  S3 cache may be serving a corrupt object — purge and retry.
- `VALIDATION_FAILURE` → payload failed schema check on appliance.
  Inspect the row's `config` for malformed JSON / missing fields.
- `COPY_FAILURE` → cannot write to the container's config file. Disk
  full, permissions, mount missing.
- `RELOAD_FAILURE` → script returned non‑zero or container restart
  failed. Check the container's own logs.

## Step 8 — Reconcile

If everything else is fine but you're impatient, force the 15‑minute
reconcile loop:

```bash
ssh <appliance>
systemctl restart atlas-onprem-config-service     # or the equivalent
```

On restart, `Reconcile()` runs immediately, fetches the latest version
for every managed app and calls `ApplyConfig` if newer.

## Useful greps cheat sheet

On the appliance (`atlas.onprem.config.service` logs):

| Grep | Tells you |
|------|-----------|
| `Subscribed to config manager` | Stream just opened |
| `Received notification for ophid` | Manager pushed something |
| `current version:` | The dedup comparison values |
| `Did not apply config as` | Dedup skip (very common) |
| `[CONFIG SUCCESS]` | Apply succeeded |
| `Send status failed` | Cannot ack back to cloud |
| `Missed .* keep alives` | Stream lost |
| `reconcile` | The 15‑min loop ran |

In the cloud (`atlas.config.manager` logs):

| Grep | Tells you |
|------|-----------|
| `Got a connection from ophid` | Appliance attached |
| `isn't served by this Config Manager` | Notification dropped on this pod |
| `Maintenance window` | UPS gating |
| `kafka` / `pubsub` consumer errors | Notification ingress broken |

In the cloud (`cdc.api` logs):

| Grep | Tells you |
|------|-----------|
| `Received POST request to create new configurations` | Insert path |
| `Update cdc_config table with` | UpdateConfigStatus path |
| `Publishing pubsub notification` | Notification sent (or not) |
