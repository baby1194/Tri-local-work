#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
N=8; START=1
for t in screen_v22 screen_r0a screen_r1a screen_r2a; do
  echo "===== SCREEN $t (n=$N) $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - "$N" "$START" 2>&1
done
echo "===== SCREEN ROUND 1 DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py screen_v22 screen_r0a screen_r1a screen_r2a
