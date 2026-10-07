#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
echo "===== vB_r1 n=8 (input 9060803 + output) $(date +%H:%M:%S) ====="
python3 gwcapture.py ../templates/vB_r1.json - 8 1 2>&1
echo "===== r1 DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vB_r1 vB_gcg9060803
