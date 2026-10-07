#!/usr/bin/env bash
POD=gcg-p3011-cleanup
for i in $(seq 1 45); do
  out=$(lium exec "$POD" "test -f /workspace/inguard/out/DONE && echo DONE; python3 -c \"import json;b=json.load(open('/workspace/inguard/out/best.json'));print('maxpu',b['maxpu'],'step',b['step'],'rule7bad',b['rule7_nonenglish_tokens'],'suffix',repr(b['suffix']))\" 2>/dev/null" 2>/dev/null | grep -v "paramiko\|UserWarning\|_policy\|Executing on")
  echo "[$i] $out"
  if echo "$out" | grep -q DONE; then echo "=== DONE ==="; exit 0; fi
  sleep 60
done
echo "TIMEOUT"
