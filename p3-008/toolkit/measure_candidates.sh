#!/bin/bash
# measure_candidates.sh <names...>  — input-probe each template in templates_en/<name>.json,
# then gwscore n=6 all-6 (sequential) on the ones that pass input 6/6, plus a w27 control.
cd /home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-008/toolkit
N="${N:-6}"
echo "=== INPUT PROBE (gate 1) ==="
pass=()
for name in "$@"; do
  line=$(python3 probe.py ../templates_en/$name.json input 2>&1 | tail -1)
  hdr=$(echo "$line" | grep -o 'PASS [0-9]/6\|[0-9]/6')
  echo "$name: $line" | cut -c1-90
  if echo "$line" | grep -q 'PASS 6/6'; then pass+=("$name"); fi
done
echo
echo "=== gate1-6/6 candidates advancing to gwscore n=$N: ${pass[*]} ==="
echo
for name in "${pass[@]}"; do
  echo "----- $name (n=$N all-6) -----"
  python3 gwscore.py ../templates_en/$name.json - "$N" 2>&1
  echo
done
echo "----- w27 control (n=$N all-6) -----"
python3 gwscore.py ../templates_en/w27_filing_lang_caseid.json - "$N" 2>&1
echo "ALLDONE"
