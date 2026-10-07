#!/usr/bin/env bash
# Watch the p3-011 GCG on 9060803: report convergence (maxPu), fetch harvest pool
# incrementally, detect DONE / error. Retrained guard may resist -> flag if it plateaus.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD=gcg-p3011-inguard
ROUT=/workspace/inguard/out
LOUT="$DIR/out_9060803"
mkdir -p "$LOUT"
for i in $(seq 1 40); do
  # incremental fetch of the harvest pool (only grows)
  lium exec "$POD" "cat $ROUT/harvest.jsonl 2>/dev/null" 2>/dev/null | grep '^{' > "$LOUT/harvest.tmp" 2>/dev/null && \
    [ -s "$LOUT/harvest.tmp" ] && mv "$LOUT/harvest.tmp" "$LOUT/harvest.jsonl"
  R=$(lium exec "$POD" "if grep -q ALL_DONE $ROUT/../out/gcg.log 2>/dev/null || [ -f $ROUT/DONE ]; then echo __DONE__; elif grep -qiE 'Traceback|CUDA error|Killed|OOM' $ROUT/gcg.log 2>/dev/null; then echo __ERR__; else grep -oE 'maxPu=[0-9.]+' $ROUT/gcg.log 2>/dev/null | tail -1; grep -cE 'restart .* FINAL' $ROUT/gcg.log 2>/dev/null | xargs echo restarts; fi" 2>/dev/null | grep -viE "missing_host_key|self\._policy" | tr '\n' ' ')
  POOL=$(grep -c '^{' "$LOUT/harvest.jsonl" 2>/dev/null || echo 0)
  echo "[$(date +%H:%M:%S) i$i] $R pool=$POOL"
  case "$R" in
    *__DONE__*) echo "GCG011_DONE pool=$POOL"; break;;
    *__ERR__*)  echo "GCG011_ERROR"; lium exec "$POD" "tail -n 25 $ROUT/gcg.log" 2>/dev/null | grep -viE "missing_host_key|self\._policy"; break;;
  esac
  sleep 60
done
echo "=== best.json ==="; lium exec "$POD" "cat $ROUT/best.json 2>/dev/null" 2>/dev/null | grep -viE "missing_host_key|self\._policy" | tail -20
