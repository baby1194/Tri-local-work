#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
echo "===== vB_bare window-2 n=20 (input off) $(date +%H:%M:%S) ====="
python3 gwcapture.py ../templates/vB_bare_w2.json - 20 1 2>&1
echo "===== vB_bare W2 DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vB_bare_w2 vB_bare
