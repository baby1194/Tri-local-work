#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in vD3_topcommit vD_ctrl; do
  echo "===== SCREEN $t (n=8) $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 8 1 2>&1
done
echo "===== SCREEN D3 DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vD3_topcommit vD_ctrl
