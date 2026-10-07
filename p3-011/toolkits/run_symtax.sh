#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
echo "===== vB_symbols agent-tax n=8 (input OFF, output ON) $(date +%H:%M:%S) ====="
python3 gwcapture.py ../templates/vB_symbols.json - 8 1 2>&1
echo "===== SYMTAX DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vB_symbols
