#!/usr/bin/env bash
POD=gcg-p3011-tiny
for i in $(seq 1 40); do
  if lium exec "$POD" "test -f /workspace/outguard/out/SWEEP_DONE && echo YES" 2>/dev/null | grep -q YES; then
    echo "===== SWEEP_DONE ====="
    lium exec "$POD" "for d in /workspace/outguard/out/len_*; do python3 -c \"import json;b=json.load(open('\$d/best.json'));print('\$d','chars',b['prefix_chars'],'maxUSER',round(b['maxUSER'],3),'step',b['step'],repr(b['prefix']))\" 2>/dev/null; done" 2>/dev/null | grep -v "paramiko\|UserWarning\|_policy\|Executing on"
    exit 0
  fi
  sleep 60
done
echo "TIMEOUT"
