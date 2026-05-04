#!/usr/bin/env bash
# Generates backlog.tsv: rows of `id\ttype\tservice`.
# Pattern per service: a small sequence of complementary tasks so that
# successive commits build up a coherent set of docs over time.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/services.sh"

OUT="$HERE/backlog.tsv"

# Per-service task sequence. Repeated rounds add new sections to the same
# files (since generators append timestamped sections).
TASK_SEQUENCE=(
  overview
  architecture-svg
  responsibilities
  dataflow-svg
  hld
  config
  metrics
  troubleshooting
  deployment
)

# Glossary entries get sprinkled in every Nth task.
GLOSSARY_EVERY=12

id=0
sprinkle=0
ROUNDS=4   # 4 rounds × 27 services × 9 tasks ≈ 972 backlog items + glossary sprinkles

: > "$OUT"
for ((r=1; r<=ROUNDS; r++)); do
  for svc in $SERVICE_ORDER; do
    for t in "${TASK_SEQUENCE[@]}"; do
      id=$((id+1))
      printf '%s\t%s\t%s\n' "$id" "$t" "$svc" >> "$OUT"
      sprinkle=$((sprinkle+1))
      if (( sprinkle % GLOSSARY_EVERY == 0 )); then
        id=$((id+1))
        printf '%s\t%s\t%s\n' "$id" "glossary" "$svc" >> "$OUT"
      fi
    done
  done
done

echo "Wrote $(wc -l < "$OUT" | tr -d ' ') backlog rows to $OUT"
