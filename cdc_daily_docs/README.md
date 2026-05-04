# cdc_daily_docs

Auto-generated, incremental study notes about the **Infoblox-CTO CDC** family
of services. The intent is to grow understanding gradually: each scheduled
run adds a small chunk (an overview paragraph, a tiny SVG diagram, an HLD
section, a metrics list, etc.) to one of the per-service folders below.

> ⚠️ Disclaimer: content is generated from naming conventions and general
> CDC patterns. Treat as study notes, not authoritative source.

## Layout

```
cdc_daily_docs/
├── README.md            ← this file
├── glossary.md          ← shared glossary, grown over time
├── <service>/           ← one folder per CDC service
│   ├── README.md
│   ├── responsibilities.md
│   ├── architecture.svg
│   ├── dataflow.svg
│   ├── HLD.md
│   ├── config.md
│   ├── metrics.md
│   ├── troubleshooting.md
│   └── deployment.md
└── _automation/         ← scheduler + worker scripts (do not edit by hand)
```

## Automation

Three commits per **weekday** (Mon–Fri) at **11:00, 14:00, 17:00** local time.
Driven by `_automation/scheduler.sh`, which runs as a detached background
process started by `_automation/start.sh`.

### Commands

```sh
# start the daemon (idempotent)
bash cdc_daily_docs/_automation/start.sh

# check status & tail logs
bash cdc_daily_docs/_automation/status.sh

# stop the daemon
bash cdc_daily_docs/_automation/stop.sh

# run one task immediately (manual trigger, useful for testing)
bash cdc_daily_docs/_automation/worker.sh
```

The daemon survives terminal close (started via `nohup` + `disown`) but
**does not** auto-start on reboot — re-run `start.sh` after a Mac restart.

### How it works

* `_automation/backlog.tsv` — pre-generated queue of tiny tasks
  (`id <TAB> task_type <TAB> service`).
* `_automation/state` — index of the next task to run (committed alongside).
* On each fire: `git pull --rebase` → run one generator → `git add` →
  `git commit` → `git push`. Weekend runs are skipped.
* A `flock` guards against overlapping runs.

### Logs

* `_automation/logs/scheduler.log` — slot timing, fires.
* `_automation/logs/worker.log`    — per-task outcome.
