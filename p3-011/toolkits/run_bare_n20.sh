#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in vB_bare frame_bare; do
  echo "===== BARE n=20 $t $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 20 1 2>&1
done
echo "===== BARE n=20 DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vB_bare frame_bare
