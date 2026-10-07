#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
echo "===== E2E vB_gcg9060803 n=8 (input 9060803 + output ON) $(date +%H:%M:%S) ====="
python3 gwcapture.py ../templates/vB_gcg9060803.json - 8 1 2>&1
echo "===== E2E DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vB_gcg9060803
