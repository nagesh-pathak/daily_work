#!/usr/bin/env bash
# Generators: each writes a small chunk to a service's docs and echoes
# the relative path of the file that was created/updated.
# All generators take: $1 = service slug, $2 = run timestamp tag.

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/services.sh"

_section_header() {
  # $1 file, $2 title
  if [[ ! -f "$1" ]]; then
    printf '# %s\n\n' "$2" > "$1"
  fi
}

gen_overview() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/README.md"
  local desc; desc="$(svc_info "$slug" 1)"
  local role; role="$(svc_info "$slug" 4)"
  _section_header "$f" "$slug"
  {
    printf '\n## Overview (%s)\n\n' "$tag"
    printf '%s\n\n' "$desc"
    printf -- '- **Role in CDC pipeline:** %s\n' "$role"
    printf -- '- **Inputs:** %s\n' "$(svc_info "$slug" 2)"
    printf -- '- **Outputs:** %s\n' "$(svc_info "$slug" 3)"
    printf '\n> Notes captured progressively as part of the daily CDC study log.\n'
  } >> "$f"
  echo "$f"
}

gen_responsibilities() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/responsibilities.md"
  local role; role="$(svc_info "$slug" 4)"
  _section_header "$f" "$slug — Responsibilities"
  {
    printf '\n### Added %s\n\n' "$tag"
    case "$role" in
      *Ingestion*)
        cat <<EOF
- Accept inbound events from the configured source.
- Validate and normalise payloads before publishing to Kafka.
- Apply backpressure / rate limiting when downstream lags.
- Emit per-tenant ingestion metrics and lag indicators.
- Handle reconnects and idempotent replays from upstream.
EOF
        ;;
      *Egress*)
        cat <<EOF
- Consume from the appropriate Kafka topics for this destination type.
- Format payloads for the destination protocol.
- Authenticate to the destination (token / mTLS / API key).
- Apply retry, backoff and dead-letter handling on failures.
- Expose delivery latency, success-rate and queue-depth metrics.
EOF
        ;;
      *Processing*|*ETL*)
        cat <<EOF
- Read raw events from upstream Kafka topics.
- Apply enrichment (geo, threat-intel, tenant metadata).
- Drop or reroute events based on policy.
- Write processed events to downstream Kafka topics.
- Emit processor lag and per-rule counters.
EOF
        ;;
      *Control*plane*|*Onboarding*|*Config*)
        cat <<EOF
- Expose APIs to manage flow / tenant / config state.
- Persist state to the backing store with versioning.
- Publish change events so data-plane components reload.
- Validate inputs against schema (CRDs / OpenAPI).
- Audit who changed what and when.
EOF
        ;;
      *)
        cat <<EOF
- Provide functionality required by neighbouring CDC components.
- Expose health, readiness and Prometheus metrics endpoints.
- Follow CDC common logging and tracing conventions.
- Stay backward compatible with prior minor versions.
EOF
        ;;
    esac
  } >> "$f"
  echo "$f"
}

gen_architecture_svg() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/architecture.svg"
  local inp; inp="$(svc_info "$slug" 2)"
  local outp; outp="$(svc_info "$slug" 3)"
  local role; role="$(svc_info "$slug" 4)"
  cat > "$f" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 220" font-family="Helvetica, Arial, sans-serif" font-size="14">
  <defs>
    <marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="#444"/>
    </marker>
  </defs>
  <rect x="1" y="1" width="718" height="218" fill="#fafafa" stroke="#ccc"/>
  <text x="360" y="28" text-anchor="middle" font-weight="bold" font-size="16">${slug} — architecture (${tag})</text>

  <rect x="30"  y="80" width="180" height="70" rx="8" fill="#e6f2ff" stroke="#1f6feb"/>
  <text x="120" y="110" text-anchor="middle" font-weight="bold">Input</text>
  <text x="120" y="132" text-anchor="middle">${inp}</text>

  <rect x="270" y="80" width="180" height="70" rx="8" fill="#fff4e5" stroke="#d97706"/>
  <text x="360" y="110" text-anchor="middle" font-weight="bold">${slug}</text>
  <text x="360" y="132" text-anchor="middle">${role}</text>

  <rect x="510" y="80" width="180" height="70" rx="8" fill="#e8f5e9" stroke="#2e7d32"/>
  <text x="600" y="110" text-anchor="middle" font-weight="bold">Output</text>
  <text x="600" y="132" text-anchor="middle">${outp}</text>

  <line x1="210" y1="115" x2="270" y2="115" stroke="#444" stroke-width="2" marker-end="url(#arr)"/>
  <line x1="450" y1="115" x2="510" y2="115" stroke="#444" stroke-width="2" marker-end="url(#arr)"/>

  <text x="360" y="195" text-anchor="middle" fill="#666" font-size="12">Generated ${tag} — daily CDC study log</text>
</svg>
EOF
  echo "$f"
}

gen_dataflow_svg() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/dataflow.svg"
  cat > "$f" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 760 320" font-family="Helvetica, Arial, sans-serif" font-size="13">
  <defs>
    <marker id="a2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="#444"/>
    </marker>
  </defs>
  <rect x="1" y="1" width="758" height="318" fill="#ffffff" stroke="#ccc"/>
  <text x="380" y="28" text-anchor="middle" font-weight="bold" font-size="16">${slug} — data flow (${tag})</text>

  <rect x="30"  y="70" width="160" height="60" rx="6" fill="#eef" stroke="#447"/><text x="110" y="105" text-anchor="middle">Source</text>
  <rect x="220" y="70" width="160" height="60" rx="6" fill="#eef" stroke="#447"/><text x="300" y="105" text-anchor="middle">Validate / Decode</text>
  <rect x="410" y="70" width="160" height="60" rx="6" fill="#eef" stroke="#447"/><text x="490" y="105" text-anchor="middle">Enrich / Filter</text>
  <rect x="600" y="70" width="140" height="60" rx="6" fill="#eef" stroke="#447"/><text x="670" y="105" text-anchor="middle">Publish</text>

  <line x1="190" y1="100" x2="220" y2="100" stroke="#444" marker-end="url(#a2)"/>
  <line x1="380" y1="100" x2="410" y2="100" stroke="#444" marker-end="url(#a2)"/>
  <line x1="570" y1="100" x2="600" y2="100" stroke="#444" marker-end="url(#a2)"/>

  <rect x="30"  y="200" width="710" height="70" rx="6" fill="#fdf6e3" stroke="#b58900"/>
  <text x="385" y="225" text-anchor="middle" font-weight="bold">Cross-cutting</text>
  <text x="385" y="248" text-anchor="middle">metrics · structured logs · tracing · retries · dead-letter</text>
  <text x="385" y="265" text-anchor="middle" font-size="11" fill="#666">Generated ${tag}</text>
</svg>
EOF
  echo "$f"
}

gen_hld() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/HLD.md"
  _section_header "$f" "$slug — High Level Design"
  {
    printf '\n## Iteration %s\n\n' "$tag"
    cat <<EOF
### Context
${slug} sits in the CDC pipeline as: **$(svc_info "$slug" 4)**.
Inputs: $(svc_info "$slug" 2). Outputs: $(svc_info "$slug" 3).

### Goals
- Reliable, ordered delivery between input and output.
- Per-tenant isolation and quotas.
- Observability first: metrics, traces, structured logs.
- Graceful degradation under partial failure.

### Non-goals
- Long-term storage of events (handled by reporting/analytics tier).
- Tenant lifecycle management (handled by onboarding plane).

### Key components (this iteration)
- Connection / consumer layer.
- Transformation pipeline.
- Output dispatcher with retry policy.
- Health & readiness probes.

### Open questions / TODO
- Confirm Kafka consumer-group naming convention.
- Document exact retry/backoff defaults.
EOF
  } >> "$f"
  echo "$f"
}

gen_config() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/config.md"
  _section_header "$f" "$slug — Configuration notes"
  {
    printf '\n### %s\n\n' "$tag"
    cat <<EOF
Common environment variables expected by ${slug}:

| Variable | Purpose |
|----------|---------|
| \`LOG_LEVEL\` | debug/info/warn/error |
| \`KAFKA_BROKERS\` | comma-separated broker list |
| \`KAFKA_TOPIC\` | input/output topic for this service |
| \`KAFKA_GROUP_ID\` | consumer group (egress / processor only) |
| \`METRICS_PORT\` | Prometheus scrape port |
| \`HEALTH_PORT\` | health/readiness port |
| \`TENANT_FILTER\` | optional tenant allow-list |

> Verify against the service's actual \`config.yaml\` / Helm values before relying on this list.
EOF
  } >> "$f"
  echo "$f"
}

gen_metrics() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/metrics.md"
  _section_header "$f" "$slug — Metrics & SLIs"
  {
    printf '\n### %s\n\n' "$tag"
    cat <<EOF
Metrics typically exposed by ${slug} (or that operators care about):

- \`${slug//[.-]/_}_events_in_total\` — events received.
- \`${slug//[.-]/_}_events_out_total\` — events successfully forwarded.
- \`${slug//[.-]/_}_errors_total{reason}\` — categorised failures.
- \`${slug//[.-]/_}_latency_seconds\` — end-to-end processing histogram.
- \`${slug//[.-]/_}_queue_depth\` — in-flight backlog.

**Suggested SLIs**
- Success rate ≥ 99.5% rolling 5m.
- p95 latency ≤ 2s for synchronous paths.
- Lag (consumer or queue) ≤ 60s.
EOF
  } >> "$f"
  echo "$f"
}

gen_troubleshooting() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/troubleshooting.md"
  _section_header "$f" "$slug — Troubleshooting"
  {
    printf '\n### %s\n\n' "$tag"
    cat <<EOF
Common symptoms and first checks:

1. **Pod CrashLoopBackOff** — check env vars, secret mounts, last log line.
2. **High consumer lag** — check broker health, partition assignment, downstream rate.
3. **Auth failures to destination** — rotate / re-mount secret, verify clock skew.
4. **Sudden error spike** — diff recent config push, check upstream schema change.
5. **Memory growth** — check goroutine leak via pprof, in-flight buffer sizes.

Useful commands:
\`\`\`
kubectl -n cdc logs deploy/${slug} --tail=200
kubectl -n cdc describe pod -l app=${slug}
kubectl -n cdc top pod -l app=${slug}
\`\`\`
EOF
  } >> "$f"
  echo "$f"
}

gen_deployment() {
  local slug="$1" tag="$2"
  local dir; dir="$(ensure_service_dir "$slug")"
  local f="$dir/deployment.md"
  _section_header "$f" "$slug — Deployment notes"
  {
    printf '\n### %s\n\n' "$tag"
    cat <<EOF
- Deployed via Helm chart in the CDC umbrella release.
- Runs as a Kubernetes Deployment (stateless) with N replicas.
- HorizontalPodAutoscaler typically driven by CPU + custom Kafka-lag metric.
- ConfigMap holds non-secret runtime config; Secret holds destination creds.
- PodDisruptionBudget recommended (\`minAvailable: 1\`) for egress paths.
- Liveness on \`/healthz\`, readiness on \`/ready\`.
EOF
  } >> "$f"
  echo "$f"
}

gen_glossary() {
  local _slug="$1" tag="$2"
  local f="$DOCS_ROOT/glossary.md"
  _section_header "$f" "CDC Glossary"
  {
    printf '\n### Added %s\n\n' "$tag"
    cat <<'EOF'
- **CDC** — Cloud Data Connector; pipeline that delivers DNS/DHCP/RPZ/security telemetry to customer destinations.
- **RPZ** — Response Policy Zone; DNS firewall mechanism whose hits are valuable security events.
- **WAPI** — Web API exposed by Infoblox NIOS appliances.
- **HEC** — HTTP Event Collector (Splunk).
- **CEF / LEEF** — Common Event Format / Log Event Extended Format used by SIEMs.
- **Flow** — A configured pipeline definition mapping a source to one or more destinations.
- **Tenant** — A customer / account boundary used for routing and isolation.
EOF
  } >> "$f"
  echo "$f"
}
