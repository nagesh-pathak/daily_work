# CDC Splunk Forwarder Base

## Purpose

CDC Splunk Forwarder Base (`cdc.splunkforwarderbase`) is a **shared Docker base image** that packages the **Splunk Universal Forwarder (UF) 9.1.0** on top of Alpine Linux with glibc compatibility. It provides the common runtime infrastructure — process management, configuration rendering, lifecycle scripts, and host config monitoring — used by all three Splunk-based CDC output containers:

| Child Image | Destination Type |
|-------------|-----------------|
| `cdc.splunk-out` | Customer Splunk Enterprise/Cloud |
| `cdc.siem-out` | Customer SIEM (CEF/LEEF format) |
| `cdc.reporting-out` | NIOS Grid Reporting Server |

Each child image adds its own health check binary, configuration templates, and optionally a certificate registration script, while inheriting the complete Splunk UF runtime from this base.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│              cdc.splunkforwarderbase Container                │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                   supervisord (PID 1)                  │  │
│  │  nodaemon=true — manages all child processes           │  │
│  └─────┬─────────┬──────────┬──────────┬─────────┬───────┘  │
│        │         │          │          │         │           │
│  ┌─────┴──┐ ┌────┴───┐ ┌───┴────┐ ┌───┴───┐ ┌──┴────────┐ │
│  │uf-main │ │health  │ │data-   │ │splunkd│ │monitor-   │ │
│  │.sh     │ │binary  │ │monitor │ │-log   │ │hostapp-   │ │
│  │(life-  │ │(from   │ │(cdc    │ │(tail  │ │config.sh  │ │
│  │cycle)  │ │child)  │ │metrics)│ │-F)    │ │(inotify)  │ │
│  └────────┘ └────────┘ └────────┘ └───────┘ └───────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │           Splunk Universal Forwarder 9.1.0             │  │
│  │  /opt/splunkforwarder/bin/splunk                       │  │
│  │  splunkd listens on port 8089                          │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ config_writer│  │ ib_control   │  │ echoLog.sh       │   │
│  │ (Python +    │  │ .reload      │  │ (logging helper) │   │
│  │  Jinja2)     │  │ (shell)      │  │                  │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
│                                                              │
│  Base Image: infobloxcto/cdc.appbase:latest (Alpine + tools) │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Container startup**: `init.sh` (ENTRYPOINT) detects the gateway IP and launches `supervisord`.
2. **supervisord** starts all managed processes:
   - `uf-main.sh start-service` — Splunk UF lifecycle manager
   - `datamonitor` — CDC metrics collector
   - `health` — Health check binary (provided by child image)
   - `splunkd-log` — Tails `splunkd.log` to stdout
   - `metrics-log` — Tails `metrics.log` to stdout
   - `monitor-hostapp-config` — Watches host display name changes
3. **uf-main.sh** on first run:
   - Accepts Splunk license, performs one-time initialization
   - Removes `vanilla_install` marker
   - Calls `ib_control.reload` to generate/apply configuration
   - Starts `splunkd` and monitors its PID file
4. **ib_control.reload** is the configuration lifecycle manager:
   - Calls `config_writer` with the child's template file to render Splunk configs
   - Reads `/infoblox/var/splunk_status`:
     - **"disabled"**: Stops Splunk, removes all config files
     - **"enabled"**: Copies staged configs from `.tmp/` to `system/local/`, restarts Splunk
5. **monitor_hostapp_config.sh** uses `inotifywait` to watch `/etc/onprem.d/hostapp_config.json`:
   - On host display name change, re-runs `config_writer` and restarts splunkd (port 8089)

## Key Files & Directory Structure

### Source Repository

```
cdc.splunkforwarderbase/
├── Dockerfile                        # Multi-layer: appbase → glibc → Splunk UF 9.1.0
├── Makefile                          # Docker build/push
├── CHANGELOG.md                      # Version history
└── src/
    ├── splunkforwarder-9.1.0.tar.gz  # Splunk Universal Forwarder binary
    ├── init.sh                       # ENTRYPOINT: detects gateway, starts supervisord
    ├── supervisord.conf              # Process manager: 6 managed programs
    ├── uf-main.sh                    # Splunk UF lifecycle (init, start, signal handling)
    ├── uf-restart.sh                 # Splunk start/stop/restart with timeout & PID management
    ├── ib_control.reload             # Config reload orchestrator (config_writer + Splunk restart)
    ├── monitor_hostapp_config.sh     # inotifywait-based host config watcher
    ├── log.cfg                       # Splunk logging categories and levels
    ├── user-seed.conf                # Splunk admin user bootstrap (hashed password)
    └── locale.md                     # Locale definitions for glibc
```

### Runtime Container Layout

```
/opt/splunkforwarder/                  # SPLUNK_HOME
├── bin/
│   └── splunk                         # Splunk UF CLI
├── etc/
│   ├── system/local/                  # Active Splunk configuration
│   │   ├── inputs.conf                # Monitor stanzas (rendered from template)
│   │   ├── outputs.conf               # Indexer targets, SSL settings
│   │   ├── server.conf                # Server name, SSL config
│   │   ├── props.conf                 # Data parsing rules
│   │   ├── limits.conf                # Resource limits
│   │   ├── cacert.pem                 # CA certificate
│   │   ├── forwarder.pem              # Client certificate + key
│   │   └── .tmp/                      # Staging directory (configs written here first)
│   ├── log.cfg                        # Splunk daemon log levels
│   ├── log-local.cfg                  # Local log overrides
│   └── supervisord.conf               # Process manager config
├── var/
│   ├── log/splunk/
│   │   ├── splunkd.log                # Splunk daemon log
│   │   └── metrics.log                # Splunk metrics log
│   └── run/splunk/
│       └── splunkd.pid                # PID file for lifecycle management
├── uf-main.sh                         # Main lifecycle script
└── uf-restart.sh                      # Restart helper with timeout

/usr/local/bin/
├── init.sh                            # Container ENTRYPOINT
├── config_writer                      # Python + Jinja2 template renderer (from cdc.appbase)
├── ib_control.reload                  # Configuration lifecycle manager
├── monitor_hostapp_config.sh          # Host config file watcher
├── echoLog.sh                         # Logging utility (from cdc.appbase)
├── datamonitor                        # CDC metrics collection binary (from cdc.appbase)
└── decrypt                            # Password decryption utility (from cdc.appbase)

/infoblox/var/
└── splunk_status                      # "enabled" | "disabled" (controls Splunk lifecycle)

/etc/onprem.d/
└── hostapp_config.json                # Host application config (display_name, etc.)
```

## Configuration

### Docker Image Layers

```
Alpine Linux (cdc.appbase)
  └── glibc 2.25 compatibility layer (alpine-pkg-glibc)
      └── Splunk Universal Forwarder 9.1.0
          └── supervisor, coreutils, ca-certificates
              └── Custom scripts (init.sh, uf-main.sh, etc.)
```

The image installs glibc compatibility on Alpine because Splunk UF requires glibc (not musl).

### supervisord Programs

| Program | Command | Auto-Restart | Purpose |
|---------|---------|--------------|---------|
| `uf-main` | `uf-main.sh start-service` | Yes (36 retries) | Splunk UF lifecycle management |
| `health` | `/bin/health` | Yes (36 retries) | Health check endpoint (from child image) |
| `datamonitor` | `datamonitor -container-id ... -cdc-stats-conf ...` | Yes (36 retries) | CDC metrics collection |
| `splunkd-log` | `tail -n 0 -F splunkd.log` | Yes | Stream Splunk logs to stdout |
| `metrics-log` | `tail -n 0 -F metrics.log` | Yes | Stream metrics logs to stdout |
| `monitor-hostapp-config` | `monitor_hostapp_config.sh` | Yes | Watch host display name changes |

### Environment Variables (Set by Base, Overridable by Children)

| Variable | Default | Description |
|----------|---------|-------------|
| `SPLUNK_HOME` | `/opt/splunkforwarder` | Splunk installation root |
| `CONFIG_TEMPLATE_FILE` | `splunk_out.tmpl` | Jinja2 template file (overridden by children) |
| `CONFIG_TEMPLATE_DIRECTORY` | `/opt/splunk_out/conf` | Template directory (overridden by children) |
| `MONITOR_CONF` | `/opt/splunk_out/conf/monitor_conf.json` | Data monitoring configuration |
| `SPLUNK_CONFIG_TEMPLATE` | `/usr/local/etc/config-template/suf_config.tmpl` | Splunk config template path |
| `IB_STATS_DIR` | `/var/captured-dns` | Default data directory |
| `IB_STATS_PATTERN` | `captured-dns*.csv` | Default file pattern |
| `LOG_LEVEL` | `INFO` | Logging verbosity |
| `HOSTAPP_CONFIG` | `/etc/onprem.d/hostapp_config.json` | Host application config path |
| `LANG` | `en_US.UTF-8` | Locale setting |

### config_writer (Template Renderer)

The `config_writer` binary (provided by `cdc.appbase`) is a Python + Jinja2 template renderer that:
1. Reads the child's template file (e.g., `reporting_out.tmpl`, `splunk_out.tmpl`, `siem_out.tmpl`)
2. Renders Splunk configuration files (`inputs.conf`, `outputs.conf`, `server.conf`, `props.conf`, `limits.conf`)
3. Writes rendered files to the `.tmp/` staging directory
4. Returns exit codes: `0` (no change), `1` (config changed), `-1` (error)

### ib_control.reload Lifecycle

```
config_writer runs
       │
       ▼
  Exit code?
  ├── -1 → Error, exit
  ├──  0 → No change, exit
  └──  1 → Config changed
              │
              ▼
        Read splunk_status
        ├── "disabled" → Stop Splunk, remove all configs
        └── "enabled"  → [Child-specific: cert registration if needed]
                         → Copy .tmp/* to system/local/
                         → Restart Splunk UF
```

### SSL Certificate Management

The base image provides the directory structure and lifecycle for SSL certificates:
- **Staging**: Certificates are generated/placed in `${SPLUNK_HOME}/etc/system/local/.tmp/`
- **Activation**: `ib_control.reload` copies from `.tmp/` to the active config directory
- **Cleanup**: When status becomes "disabled", all certs are removed

Child images are responsible for certificate generation/procurement:
- `cdc.reporting-out`: Auto-generates CSR and gets it signed by Grid
- `cdc.splunk-out`: Uses customer-provided certificates
- `cdc.siem-out`: Uses customer-provided certificates

### Non-Root User Setup

The Splunk admin user is bootstrapped via `user-seed.conf`:
```ini
[user_info]
USERNAME = admin
HASHED_PASSWORD = $6$BOj2/bKZc9saGIXT$...
```

### Splunk Home Directory Structure

```
/opt/splunkforwarder/
├── bin/                    # Splunk binaries
├── etc/                    # Configuration
│   ├── apps/               # Splunk apps
│   ├── auth/               # Authentication data
│   ├── system/
│   │   ├── default/        # Splunk defaults
│   │   └── local/          # Active custom config (inputs.conf, outputs.conf, etc.)
│   │       └── .tmp/       # Staging area for config changes
│   ├── log.cfg             # Logging configuration
│   ├── log-local.cfg       # Local logging overrides
│   └── supervisord.conf    # Process manager config
├── var/
│   ├── lib/splunk/         # Splunk state data
│   ├── log/splunk/         # Runtime logs (splunkd.log, metrics.log)
│   └── run/splunk/         # PID files
├── uf-main.sh              # Lifecycle manager
├── uf-restart.sh            # Restart helper
└── vanilla_install          # First-run marker (removed after init)
```

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `cdc.appbase` | Alpine base with `config_writer`, `datamonitor`, `decrypt`, `echoLog.sh` |
| Splunk UF 9.1.0 | Universal Forwarder binary (`splunkforwarder-9.1.0.tar.gz`) |
| `glibc 2.25` | glibc compatibility for Alpine (required by Splunk UF) |
| `supervisor` | Process manager for all container processes |
| `coreutils` | GNU core utilities |
| `inotifywait` | File system event watcher (via `inotify-tools`, from appbase) |
| `jq` | JSON parsing for hostapp_config.json |

## Build & Deploy

### Build

```bash
# Build the base image
make build

# Push to registry
make push
make push-latest
```

### Image Registry

```
infobloxcto/cdc.splunkforwarderbase:<version>
infobloxcto/cdc.splunkforwarderbase:latest
```

### Usage in Child Images

Child Dockerfiles extend this base:

```dockerfile
FROM infobloxcto/cdc.splunkforwarderbase:latest

# Override template and config directory
ENV CONFIG_TEMPLATE_FILE=<child_template>.tmpl
ENV CONFIG_TEMPLATE_DIRECTORY=/opt/<child>/conf

# Add child-specific health binary
COPY --from=health-builder /path/to/health /bin/health

# Add child-specific scripts
ADD src/ib_control.reload /usr/local/bin/  # Override with child-specific version
```

### Version History

| Version | Key Changes |
|---------|------------|
| v2.1.6 | Updated appbase, added decryption for reporting-out |
| v2.1.5 | Fix for uf-main continuous restart when disabled |
| v2.1.3 | Updated appbase for monitoring conf |
| v2.1.0 | Datamonitor delay, splunkd process monitor, Splunk UF version update |
| v2.0.0 | Timestamp collection support, appbase version updates |
