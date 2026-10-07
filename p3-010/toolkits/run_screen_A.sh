#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in vA_archival screen_v22d; do
  echo "===== SCREEN $t (n=8) $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 8 1 2>&1
done
echo "===== SCREEN A DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vA_archival screen_v22d
