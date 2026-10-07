#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in w01_ctrl w02_observer w03_adjudicated w04_forensic w05_continue w06_minimal w07_ledger w08_auditreply w09_timeline w10_priorcase; do
  echo "===== SCREEN $t (n=8) $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 8 1 2>&1
done
echo "===== WRAPPERS DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py w01_ctrl w02_observer w03_adjudicated w04_forensic w05_continue w06_minimal w07_ledger w08_auditreply w09_timeline w10_priorcase
