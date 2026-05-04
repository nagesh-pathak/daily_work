#!/usr/bin/env bash
# Shared helpers.

REPO_ROOT="${REPO_ROOT:-/Users/npathak/go/src/github.com/Nagesh-DW/daily_work}"
DOCS_ROOT="${REPO_ROOT}/cdc_daily_docs"
AUTO_DIR="${DOCS_ROOT}/_automation"
LOG_DIR="${AUTO_DIR}/logs"
STATE_FILE="${AUTO_DIR}/state"
BACKLOG_FILE="${AUTO_DIR}/backlog.tsv"
PID_FILE="${AUTO_DIR}/.pid"
LOCK_FILE="${AUTO_DIR}/.lock"

mkdir -p "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

slug_to_dir() {
  # Convert "cdc.dns-in" -> "cdc_dns_in" for filesystem friendliness.
  echo "$1" | tr '.-' '__'
}

ensure_service_dir() {
  local slug="$1"
  local dir="${DOCS_ROOT}/$(slug_to_dir "$slug")"
  mkdir -p "$dir"
  echo "$dir"
}
