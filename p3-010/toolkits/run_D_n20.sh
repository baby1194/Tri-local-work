#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in vD_n20 v22_n20; do
  echo "===== N20 $t $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 20 101 2>&1
done
echo "===== N20 DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vD_n20 v22_n20
