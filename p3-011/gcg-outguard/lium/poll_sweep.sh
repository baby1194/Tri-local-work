#!/usr/bin/env bash
# Poll the pod until SWEEP_DONE, then dump each length's best.json summary.
POD=gcg-p3011-minlen
for i in $(seq 1 60); do
  done=$(lium exec "$POD" "test -f /workspace/outguard/out/SWEEP_DONE && echo YES || echo NO" 2>/dev/null | grep -v "paramiko\|UserWarning\|_policy\|Executing on" | tr -d '[:space:]')
  if [ "$done" = "YES" ]; then
    echo "===== SWEEP_DONE ====="
    lium exec "$POD" "for d in /workspace/outguard/out/len_*; do echo \"--- \$d ---\"; cat \$d/best.json 2>/dev/null; echo; done" 2>/dev/null | grep -v "paramiko\|UserWarning\|_policy\|Executing on"
    exit 0
  fi
  sleep 60
done
echo "===== POLL TIMEOUT (60 min) — last log ====="
lium exec "$POD" "tail -n 30 /workspace/outguard/out/minlen.log" 2>/dev/null | grep -v "paramiko\|UserWarning\|_policy\|Executing on"
