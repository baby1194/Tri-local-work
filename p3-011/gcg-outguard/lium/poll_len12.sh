#!/usr/bin/env bash
POD=gcg-p3011-minlen
for i in $(seq 1 40); do
  d=$(lium exec "$POD" "test -f /workspace/outguard/out/len_12/DONE && echo YES || echo NO" 2>/dev/null | grep -v "paramiko\|UserWarning\|_policy\|Executing on" | tr -d '[:space:]')
  if [ "$d" = "YES" ]; then
    echo "===== len_12 DONE ====="
    lium exec "$POD" "cat /workspace/outguard/out/len_12/best.json; echo; cat /workspace/outguard/out/len_12/DONE" 2>/dev/null | grep -v "paramiko\|UserWarning\|_policy\|Executing on"
    exit 0
  fi
  sleep 45
done
echo "TIMEOUT len_12"; lium exec "$POD" "cat /workspace/outguard/out/len_12/best.json" 2>/dev/null | grep -v "paramiko\|UserWarning\|_policy\|Executing on"
