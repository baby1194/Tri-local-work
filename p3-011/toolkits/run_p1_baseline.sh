#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
echo "===== P1 vD_stamp baseline on p3-011, n=8 all-six $(date +%H:%M:%S) ====="
python3 gwcapture.py ../templates/p3010_vD_stamp_REFERENCE.json - 8 1 2>&1
echo "===== P1 DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py p3010_vD_stamp_REFERENCE
