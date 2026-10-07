#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
for t in vA_mechspec vB_neutralex vAB_both; do
  echo "===== SCREEN $t (n=8) $(date +%H:%M:%S) ====="
  python3 gwcapture.py "../templates/$t.json" - 8 1 2>&1
done
echo "===== P11 VARIANTS DONE $(date +%H:%M:%S) ====="
python3 tally_screen.py p3010_vD_stamp_REFERENCE vA_mechspec vB_neutralex vAB_both
