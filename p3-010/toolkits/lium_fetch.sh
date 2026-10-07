#!/usr/bin/env bash
# Pull GCG artifacts from the pod into local-work/p3-010/lium-gcg/.
# Does not terminate the pod.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$DIR/env.sh"

if [[ ! -f "$LOCAL_OUT/pod.json" ]]; then
  echo "no $LOCAL_OUT/pod.json" >&2
  exit 2
fi

mkdir -p "$LOCAL_OUT"
echo "=== pull $POD_NAME:$REMOTE_OUT -> $LOCAL_OUT ==="

pull() {
  local remote="$1"
  lium scp "$POD_NAME" "$remote" "$LOCAL_OUT/" -d || echo "missing $remote" >&2
}

pull "$REMOTE_LOG"
pull "$REMOTE_OUT/best.json"
pull "$REMOTE_OUT/suffix.txt"
pull "$REMOTE_OUT/deploy.json"
pull "$REMOTE_OUT/DONE"
pull "$REMOTE_OUT/step_0000.json"

lium exec "$POD_NAME" "ls -1 $REMOTE_OUT/step_*.json 2>/dev/null | tail -n 8" \
  > "$LOCAL_OUT/step_list.txt" || true
if [[ -s "$LOCAL_OUT/step_list.txt" ]]; then
  while read -r rp; do
    [[ -n "$rp" ]] || continue
    lium scp "$POD_NAME" "$rp" "$LOCAL_OUT/" -d || true
  done < "$LOCAL_OUT/step_list.txt"
fi

echo "=== local artifacts ==="
ls -lh "$LOCAL_OUT" || true
if [[ -f "$LOCAL_OUT/best.json" ]]; then
  python3 -c "
import json
from pathlib import Path
d = json.loads(Path(r'''$LOCAL_OUT''', 'best.json').read_text())
print('suffix', repr(d.get('suffix')))
print('weighted_ce', d.get('weighted_ce'))
print('step', d.get('step'), 'chars', d.get('n_chars'))
print('ce', d.get('ce'))
"
  python3 "$DIR/apply_suffix.py" "$LOCAL_OUT/best.json" || true
fi
if [[ -f "$LOCAL_OUT/DONE" ]]; then
  echo "DONE:"
  cat "$LOCAL_OUT/DONE"
fi
touch "$LOCAL_OUT/FETCHED"
echo "fetched. next: inspect templates/a021_gcg.json then lium_rm.sh"
