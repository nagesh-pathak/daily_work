# DB Calls and Request Timings

All numbers below are **typical observed ranges in a healthy cluster**.
They are not SLAs. Use them as a yard‑stick: if a hop is taking 10×
these numbers, that hop is the suspect.

## Postgres calls on `cdc_config`

| # | Caller | Op | Effective SQL | Triggers / Notes | Typical |
|---|--------|------|----------------|------------------|---------|
| 1 | `cdc.api.CreateConfig` (dup check) | `SELECT` | `SELECT * FROM cdc_config WHERE ophid=? AND container_name=? ORDER BY version DESC LIMIT 1` | Index on `(ophid, container_name)` recommended | 2–10 ms |
| 2 | `cdc.api.CreateConfig` (insert) | `INSERT` | `INSERT INTO cdc_config(...) VALUES (...)` | Fires `cdc_config_version` trigger → another `SELECT MAX(version)` | 5–20 ms |
| 3 | `cdc.api.CreateConfig` (read‑back) | `SELECT` | `... ORDER BY id DESC LIMIT 1` (gorm `Last`) | Returns server‑generated `version` | 2–10 ms |
| 4 | `cdc.api.GetConfig` | `SELECT` | `... ORDER BY version DESC LIMIT 1` (latest) **or** exact version | Hot path during reconcile | 2–10 ms |
| 5 | `cdc.api.UpdateConfigStatus` | `UPDATE` | `UPDATE cdc_config SET message=?, status_code=? WHERE ophid=? AND version=? AND container_name=?` | `updated_at` set by `set_updated_at` trigger | 5–15 ms |
| 6 | `cdc.api.GetConfigStatus` | `SELECT` | same shape as #4 | Used by UI / status‑reporter | 2–10 ms |
| 7 | `cdc.api.DeleteConfig` | `INSERT` | `INSERT ... config='{"delete":"true"}', status_code=98, message='Delete Initiated'` | New row, append‑only | 5–20 ms |
| 8 | `cdc.api` status‑reporter (`tfc/flow_status`) | `SELECT` | per‑ophid latest row scan, then aggregation | Once per aggregation tick (configurable) | 10–50 ms (table size dependent) |

### Why `CreateConfig` does 3 DB calls

1. dup check (#1)
2. insert (#2) which itself does an extra `SELECT MAX(version)` inside
   the trigger
3. read‑back (#3) to return the assigned `version` to the caller

So a single `POST /config` is at least **4** Postgres round‑trips. If
you see > 100 ms wall‑clock for the API call, look at Postgres latency
first (`pg_stat_statements`).

## Other request hops (no DB)

| # | Hop | Transport | Typical |
|---|-----|-----------|---------|
| A | `cdc.api` → PubSub broker (publish) | gRPC to atlas.pubsub | 5–30 ms |
| B | PubSub broker → `atlas.config.manager` consumer | push / poll | 50–500 ms |
| C | Manager → in‑memory `onpremNotificationCh[ophid]` | none | < 1 ms |
| D | Manager `Subscribe` stream → onprem | gRPC stream over TLS, customer WAN | 100–800 ms |
| E | Onprem `GetConfig` → manager (fragmented) | gRPC unary, multiple SHA‑1 fragments | 200 ms – several seconds (proportional to payload size) |
| F | Manager → app `configAPI` (e.g. `cdc.api.GetConfig`) for the actual JSON | gRPC / REST in‑cluster | 5–50 ms |
| G | Onprem write file + reload **script** | local | 1–5 s |
| G' | Onprem write file + container **restart** | docker / k8s | 5–30 s |
| H | Onprem `SendStatus` → manager → `cdc.api.UpdateConfigStatus` | gRPC chain | 200–800 ms |

## End‑to‑end latency budgets

Happy path, `ReloadPolicy="script"`:

```
POST /config returns 200             ~50 ms   (steps 1+2+3+A)
status_code 99 → 0 in cdc_config    ~2–5 s   (steps B+D+E+F+G+H)
```

Happy path, `ReloadPolicy="restart"`:

```
POST /config returns 200             ~50 ms
status_code 99 → 0 in cdc_config    ~10–35 s (G' dominates)
```

Reconcile catch‑up (no PubSub notification, ophid was offline at the time):

```
status_code 99 → 0 in cdc_config    up to 15 min + apply time
```

## Why a config push to onprem can be "delayed" even though the DB row is fresh

Mapping each common cause to which hop it stalls in:

| Symptom | Stalls at | What you'll see |
|---------|----------|-----------------|
| `atlas.pubsub.enable=false` | A (skipped) | Row stays at `status_code=99` for up to 15 min until reconcile |
| Kafka/PubSub backlog | B | All ophids delayed simultaneously |
| Manager pod for ophid is the wrong one | C | "isn't served by this Config Manager" log; recovery via reconcile |
| Subscribe stream broken | D | "Missed N keep alives" on appliance, exponential backoff up to 60 s |
| Config payload very large | E | Multi‑second fetch, possible HASH_FAILURE |
| App `configAPI` slow | F | All apps for that container_name slow |
| Container restart slow | G' | Multi‑second to multi‑minute apply, status flips eventually |
| Status callback fails | H | Onprem applied but `cdc_config` keeps showing old `status_code` |
| Local version file ≥ pushed version | between E and G | Apply skipped, `Did not apply config as ...` written into `message` (status_code=0) |

For step‑by‑step debugging see [DEBUGGING.md](./DEBUGGING.md).

## Suggested observability to add (if not already)

- Histogram on each of the 8 SQL ops in the table above (label by op
  name + container_name).
- Counter on PubSub publish success/fail in `cdc.api`.
- Counter on `notification dropped — ophid not served by this manager`
  in `atlas.config.manager`.
- Histogram on **time between insert in `cdc_config` and the matching
  `UpdateConfigStatus` for that `(ophid, container_name, version)`** —
  this is *the* end‑to‑end SLI for config push.
