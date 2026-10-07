#!/usr/bin/env bash
# Incremental-fetch watcher for the H100 harvest. Pulls harvest.jsonl every poll
# (it only grows, so latest = complete), so a TTL/crash can't lose data.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD=gcg-p3010-hv2
ROUT=/workspace/inguard/out
LOUT="$DIR/out_hv2"
mkdir -p "$LOUT"
for i in $(seq 1 150); do
  # incremental fetch (cat is robust vs rsync path quirks)
  lium exec "$POD" "cat $ROUT/harvest.jsonl 2>/dev/null" 2>/dev/null | grep '^{' > "$LOUT/harvest.tmp" && \
    [ -s "$LOUT/harvest.tmp" ] && mv "$LOUT/harvest.tmp" "$LOUT/harvest.jsonl"
  R=$(lium exec "$POD" "if [ -f $ROUT/DONE ]; then echo __DONE__; elif grep -qiE 'Traceback|CUDA error|Killed|OOM' $ROUT/gcg.log 2>/dev/null; then echo __ERR__; else grep -cE 'restart .* FINAL' $ROUT/gcg.log 2>/dev/null | xargs echo __WAIT__ restarts; fi" 2>/dev/null || echo "__EXECFAIL__")
  POOL=$(grep -c '^{' "$LOUT/harvest.jsonl" 2>/dev/null || echo 0)
  echo "[$(date +%H:%M:%S) iter $i] $R  pool=$POOL"
  case "$R" in
    *__DONE__*) echo "HV2_COMPLETE pool=$POOL"; break;;
    *__ERR__*)  echo "HV2_ERROR"; lium exec "$POD" "tail -n 30 $ROUT/gcg.log" 2>/dev/null; break;;
    *__EXECFAIL__*) echo "HV2_POD_GONE (using last fetched pool=$POOL)"; break;;
  esac
  sleep 45
done
echo "=== families in fetched pool ==="
grep -o '"restart": [0-9]*' "$LOUT/harvest.jsonl" 2>/dev/null | sort -n | uniq -c
