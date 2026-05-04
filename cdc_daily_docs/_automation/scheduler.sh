#!/usr/bin/env bash
# Long-running scheduler: sleeps until the next configured slot on a weekday,
# then invokes worker.sh. Loops forever until killed (or the Mac shuts down).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"

SCHED_LOG="$LOG_DIR/scheduler.log"

# Slot times (24h). Match the user's choice: 11:00, 14:00, 17:00.
SLOTS=(11:00 14:00 17:00)

# Compute epoch seconds for the next eligible slot (Mon–Fri).
next_slot_epoch() {
  local now_epoch; now_epoch="$(date +%s)"
  for offset in 0 1 2 3 4 5 6 7; do
    local day_epoch=$(( now_epoch + offset*86400 ))
    local dow; dow="$(date -r "$day_epoch" +%u)"   # 1=Mon..7=Sun
    if [[ "$dow" -ge 6 ]]; then
      continue
    fi
    local ymd; ymd="$(date -r "$day_epoch" +%Y-%m-%d)"
    for s in "${SLOTS[@]}"; do
      local cand_epoch
      cand_epoch="$(date -j -f '%Y-%m-%d %H:%M' "$ymd $s" +%s 2>/dev/null || true)"
      [[ -z "$cand_epoch" ]] && continue
      if [[ "$cand_epoch" -gt "$now_epoch" ]]; then
        echo "$cand_epoch"
        return 0
      fi
    done
  done
  # Fallback: 1h from now.
  echo $(( now_epoch + 3600 ))
}

main() {
  exec >>"$SCHED_LOG" 2>&1
  log "scheduler started (pid $$); slots=${SLOTS[*]}; weekdays only"
  trap 'log "scheduler received signal — exiting"; exit 0' INT TERM

  while true; do
    local target; target="$(next_slot_epoch)"
    local now; now="$(date +%s)"
    local sleep_for=$(( target - now ))
    [[ "$sleep_for" -lt 1 ]] && sleep_for=1
    local target_human; target_human="$(date -r "$target" '+%Y-%m-%d %H:%M:%S %Z')"
    log "next slot at $target_human (sleeping ${sleep_for}s)"

    # Sleep in chunks so signals are handled promptly.
    while [[ "$sleep_for" -gt 0 ]]; do
      local chunk=300
      [[ "$sleep_for" -lt "$chunk" ]] && chunk="$sleep_for"
      sleep "$chunk"
      sleep_for=$(( sleep_for - chunk ))
    done

    log "firing worker"
    if ! "$HERE/worker.sh"; then
      log "worker exited non-zero (continuing)"
    fi
  done
}

main "$@"
