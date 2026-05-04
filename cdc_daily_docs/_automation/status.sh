#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Running. pid=$(cat "$PID_FILE")"
else
  echo "Not running."
fi
echo
echo "State index: $(cat "$STATE_FILE" 2>/dev/null || echo '(none)') / $(wc -l < "$BACKLOG_FILE" 2>/dev/null | tr -d ' ' || echo 0)"
echo
echo "--- last 20 scheduler log lines ---"
tail -n 20 "$LOG_DIR/scheduler.log" 2>/dev/null || echo "(no scheduler log yet)"
echo
echo "--- last 20 worker log lines ---"
tail -n 20 "$LOG_DIR/worker.log" 2>/dev/null || echo "(no worker log yet)"
