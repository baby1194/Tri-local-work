#!/usr/bin/env bash
# The MISSING measurement: vB_r1 at matched n=20 (real pipeline, live 9060803 + output).
# The whole "~10 ceiling" rested on n=8 screens; p3-010 proved n=8 swings +-1 board pt.
set -uo pipefail
cd "$(dirname "$0")"
echo "===== vB_r1 n=20 (input 9060803 + output ON) START $(date +%H:%M:%S) ====="
python3 gwcapture.py ../templates/vB_r1.json - 20 1 2>&1
echo "===== vB_r1 n=20 DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vB_r1 2>&1
