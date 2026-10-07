#!/usr/bin/env bash
# Poll the remote harvest pod until DONE (or fatal error), then fetch the pool.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD=gcg-p3010-harvest
ROUT=/workspace/inguard/out
LOUT="$DIR/out_harvest"
mkdir -p "$LOUT"
for i in $(seq 1 130); do
  R=$(lium exec "$POD" "if [ -f $ROUT/DONE ]; then echo __DONE__; elif grep -qiE 'Traceback|CUDA error|Killed|OutOfMemory|OOM' $ROUT/gcg.log 2>/dev/null; then echo __ERR__; else echo __WAIT__ \$(wc -l < $ROUT/harvest.jsonl 2>/dev/null || echo 0); fi" 2>/dev/null || echo "__EXECFAIL__")
  echo "[$(date +%H:%M:%S) iter $i] $R"
  case "$R" in
    *__DONE__*) echo "HARVEST_COMPLETE"; break;;
    *__ERR__*)  echo "HARVEST_ERROR"; lium exec "$POD" "tail -n 40 $ROUT/gcg.log" 2>/dev/null; break;;
  esac
  sleep 60
done
echo "=== fetching $ROUT -> $LOUT ==="
lium rsync "$POD" "$POD:$ROUT/" "$LOUT" 2>/dev/null || lium scp "$POD" "$ROUT/harvest.jsonl" "$LOUT/harvest.jsonl" 2>/dev/null || true
# fallback: cat the files back over exec if rsync unsupported
[ -s "$LOUT/harvest.jsonl" ] || lium exec "$POD" "cat $ROUT/harvest.jsonl" 2>/dev/null > "$LOUT/harvest.jsonl"
[ -s "$LOUT/best.json" ]     || lium exec "$POD" "cat $ROUT/best.json"     2>/dev/null > "$LOUT/best.json"
[ -s "$LOUT/gcg.log" ]       || lium exec "$POD" "cat $ROUT/gcg.log"       2>/dev/null > "$LOUT/gcg.log"
echo "=== FETCHED. harvest.jsonl lines: $(wc -l < "$LOUT/harvest.jsonl" 2>/dev/null || echo 0) ==="
