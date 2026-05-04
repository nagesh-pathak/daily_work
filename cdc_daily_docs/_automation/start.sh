#!/usr/bin/env bash
# Start scheduler in the background, detached from this terminal.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Scheduler already running (pid $(cat "$PID_FILE"))."
  exit 0
fi

# Build backlog if missing.
if [[ ! -s "$BACKLOG_FILE" ]]; then
  bash "$HERE/build_backlog.sh"
fi

nohup bash "$HERE/scheduler.sh" >/dev/null 2>&1 &
echo $! > "$PID_FILE"
disown || true
echo "Scheduler started (pid $(cat "$PID_FILE")). Logs: $LOG_DIR/"
