#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in vD_stamp screen_v22f; do
  echo "===== SCREEN $t (n=8) $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 8 1 2>&1
done
echo "===== SCREEN D DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vD_stamp screen_v22f
