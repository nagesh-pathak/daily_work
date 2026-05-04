#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"

if [[ ! -f "$PID_FILE" ]]; then
  echo "No PID file — scheduler not running (or was started manually)."
  exit 0
fi

pid="$(cat "$PID_FILE")"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" || true
  fi
  echo "Stopped scheduler (pid $pid)."
else
  echo "Scheduler not running (stale PID $pid)."
fi
rm -f "$PID_FILE"
