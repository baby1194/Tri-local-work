#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in vDC_stack screen_v22g; do
  echo "===== SCREEN $t (n=8) $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 8 1 2>&1
done
echo "===== SCREEN DC DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vDC_stack screen_v22g
