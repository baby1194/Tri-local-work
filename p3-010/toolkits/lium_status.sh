#!/usr/bin/env bash
# Show pod spend, nvidia-smi, and the last GCG log lines.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$DIR/env.sh"

FOLLOW=0
LINES=80
if [[ "${1:-}" == "--follow" || "${1:-}" == "-f" ]]; then
  FOLLOW=1
fi

if [[ ! -f "$LOCAL_OUT/pod.json" ]]; then
  echo "no pod.json; lium ps:" >&2
  lium ps --format json
  exit 2
fi

echo "=== ps $POD_NAME ==="
lium ps --filter "name=$POD_NAME" --format json || lium ps "$POD_NAME" --format json || true
echo "=== spend ==="
lium spend --format json || true
echo "=== gpu ==="
lium exec "$POD_NAME" "nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv" || true
echo "=== DONE? ==="
lium exec "$POD_NAME" "test -f $REMOTE_DONE && cat $REMOTE_DONE || echo 'not-done'" || true
echo "=== tail $REMOTE_LOG ==="
lium exec "$POD_NAME" "mkdir -p $REMOTE_OUT; tail -n $LINES $REMOTE_LOG 2>/dev/null || echo 'no log yet'"

if [[ "$FOLLOW" -eq 1 ]]; then
  echo "--- follow (Ctrl-C local only; job keeps running) ---"
  while true; do
    sleep 30
    lium exec "$POD_NAME" "tail -n 20 $REMOTE_LOG 2>/dev/null; echo '---'; test -f $REMOTE_DONE && cat $REMOTE_DONE && exit 0; echo not-done"
    if lium exec "$POD_NAME" "test -f $REMOTE_DONE" >/dev/null 2>&1; then
      echo "DONE file present"
      break
    fi
  done
fi
