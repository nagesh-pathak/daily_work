#!/usr/bin/env bash
# Worker: executes a single backlog item, commits, and pushes.
# Designed to be triggered by scheduler.sh (or manually).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/services.sh"
# shellcheck disable=SC1091
source "$HERE/lib/generators.sh"

WORKER_LOG="$LOG_DIR/worker.log"

run() {
  exec >>"$WORKER_LOG" 2>&1

  # Skip on weekends (Sat=6, Sun=7 in %u).
  local dow; dow="$(date +%u)"
  if [[ "$dow" -ge 6 ]]; then
    log "weekend (dow=$dow) — skipping run"
    return 0
  fi

  # Single-instance lock (mkdir is atomic; portable on macOS without flock).
  if ! mkdir "$LOCK_FILE" 2>/dev/null; then
    # Stale lock if older than 30 min.
    if find "$LOCK_FILE" -maxdepth 0 -mmin +30 >/dev/null 2>&1; then
      log "removing stale lock"
      rm -rf "$LOCK_FILE"
      mkdir "$LOCK_FILE" 2>/dev/null || { log "could not acquire lock"; return 0; }
    else
      log "another worker run is in progress — exiting"
      return 0
    fi
  fi
  trap 'rm -rf "$LOCK_FILE"' EXIT

  cd "$REPO_ROOT"

  # Ensure backlog & state exist.
  if [[ ! -f "$BACKLOG_FILE" ]]; then
    log "backlog missing at $BACKLOG_FILE — aborting"
    return 1
  fi
  [[ -f "$STATE_FILE" ]] || echo "0" > "$STATE_FILE"

  # Pull latest before touching files.
  if ! git pull --rebase --autostash origin main; then
    log "git pull failed — aborting this run"
    return 1
  fi

  local total; total="$(wc -l < "$BACKLOG_FILE" | tr -d ' ')"
  local idx;   idx="$(cat "$STATE_FILE")"
  if [[ "$idx" -ge "$total" ]]; then
    log "backlog exhausted (idx=$idx total=$total) — wrapping to 0"
    idx=0
  fi

  # Lines are 1-indexed for sed.
  local line_no=$(( idx + 1 ))
  local line; line="$(sed -n "${line_no}p" "$BACKLOG_FILE")"
  if [[ -z "$line" ]]; then
    log "empty backlog line at $line_no — skipping"
    echo "$(( idx + 1 ))" > "$STATE_FILE"
    return 0
  fi

  local task_id task_type service
  IFS=$'\t' read -r task_id task_type service <<<"$line"
  local tag; tag="$(date '+%Y-%m-%d %H:%M')"

  log "starting task #$task_id type=$task_type service=$service"

  local out_file=""
  case "$task_type" in
    overview)        out_file="$(gen_overview        "$service" "$tag")" ;;
    responsibilities)out_file="$(gen_responsibilities "$service" "$tag")" ;;
    architecture-svg)out_file="$(gen_architecture_svg "$service" "$tag")" ;;
    dataflow-svg)    out_file="$(gen_dataflow_svg    "$service" "$tag")" ;;
    hld)             out_file="$(gen_hld             "$service" "$tag")" ;;
    config)          out_file="$(gen_config          "$service" "$tag")" ;;
    metrics)         out_file="$(gen_metrics         "$service" "$tag")" ;;
    troubleshooting) out_file="$(gen_troubleshooting "$service" "$tag")" ;;
    deployment)      out_file="$(gen_deployment      "$service" "$tag")" ;;
    glossary)        out_file="$(gen_glossary        "$service" "$tag")" ;;
    *)
      log "unknown task type: $task_type — skipping"
      echo "$(( idx + 1 ))" > "$STATE_FILE"
      return 0
      ;;
  esac

  if [[ -z "$out_file" || ! -f "$out_file" ]]; then
    log "generator produced no file for task #$task_id — skipping"
    echo "$(( idx + 1 ))" > "$STATE_FILE"
    return 0
  fi

  local rel; rel="${out_file#$REPO_ROOT/}"
  git add "$rel" "$STATE_FILE" 2>/dev/null || true

  # Persist new index BEFORE commit so it's part of the same commit.
  echo "$(( idx + 1 ))" > "$STATE_FILE"
  git add "$STATE_FILE"

  if git diff --cached --quiet; then
    log "no staged changes — nothing to commit"
    return 0
  fi

  local human_type; human_type="${task_type//-/ }"
  local msg="cdc study: ${service} — ${human_type} (#${task_id})"
  if ! git commit -m "$msg"; then
    log "git commit failed"
    return 1
  fi

  if ! git push origin main; then
    log "push failed; will retry once after pull --rebase"
    git pull --rebase --autostash origin main || true
    if ! git push origin main; then
      log "push retry failed — leaving commit local"
      return 1
    fi
  fi

  log "completed task #$task_id -> $rel"
}

run "$@"
