#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in vBc_reframe vBfw_firewall vBcfw_both; do
  echo "===== SCREEN $t (n=8, input 9060803+output) $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 8 1 2>&1
done
echo "===== FW VARIANTS DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py vB_r1 vBc_reframe vBfw_firewall vBcfw_both
