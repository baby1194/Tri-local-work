#!/usr/bin/env bash
# End-to-end a021 H100 GCG. Does nothing billed unless you pass --admit.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ADMIT=0
SMOKE=0
KEEP=0
NO_WAIT=0
PEEK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --admit) ADMIT=1 ;;
    --smoke) SMOKE=1 ;;
    --keep-pod) KEEP=1 ;;
    --no-wait) NO_WAIT=1 ;;
    --peek) PEEK=1 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--admit] [--smoke] [--peek] [--keep-pod] [--no-wait]

  no flags     print the plan, list a Secure H100, do not rent
  --admit      rent, upload, run GCG, wait, fetch, terminate
  --smoke      5 GCG steps, TTL 2h, budget \$6 (still needs --admit)
  --peek       INIT peeks only (load model, no loop)
  --keep-pod   do not lium rm at the end
  --no-wait    detach GCG and return (you fetch/rm later)

Env overrides: POD_NAME TTL BUDGET GCG_STEPS GCG_BATCH GCG_MICRO
EOF
      exit 0
      ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$SMOKE" -eq 1 ]]; then
  export TTL="${TTL:-2h}"
  export BUDGET="${BUDGET:-6}"
  export GCG_STEPS="${GCG_STEPS:-5}"
fi
# shellcheck source=env.sh
source "$DIR/env.sh"

plan() {
  cat <<EOF
a021 H100 GCG plan (not started)

  pod        $POD_NAME
  node       Secure 1x $GPU ${MIN_VRAM}GB, $COUNTRY, <= \$$MAX_PRICE/h
  image      template_id=$TEMPLATE_ID
  ttl/budget $TTL / \$$BUDGET   (earlier deadline wins; ttl is armed at create)
  model      $MODEL  bf16 on one H100
  job        $TK/gcg_a021_stamp.py
  loss       CE(answer starts with 'Debrief DB-021\\n1) ') over Q1-Q6
             weights Q4=${GCG_W_Q4:-2.5} Q1=${GCG_W_Q1:-2.0} others=1.0
  steps      $GCG_STEPS  batch=$GCG_BATCH micro=$GCG_MICRO
  remote     $REMOTE_ROOT   log=$REMOTE_LOG
  local      $LOCAL_OUT
  deploy     templates/a021_gcg.json via apply_suffix.py after fetch

  then (not this script):
    python3 $TK/gwcapture.py $P3010/templates/a021_gcg.json - 8
    input.enabled stays false until the input-guard pass
    output-guard engineering is the pass after agent 6/6

  cost note: listing today is about \$1.30/h Secure H100. 10h ttl ~ \$13
  if the job runs the whole window. balance is checked below.

EOF
}

echo "=== lium account ==="
lium whoami
lium balance --format json || lium balance
lium ssh-keys list || true

echo "=== candidate nodes ==="
lium ls --gpu "$GPU" --count 1 --min-vram "$MIN_VRAM" --tier "$TIER" \
  --country "$COUNTRY" --max-price "$MAX_PRICE" --format json \
  | python3 -c "
import json,sys
nodes=json.load(sys.stdin)
print('count', len(nodes))
for n in nodes[:5]:
    print(f\"  {n.get('huid')}  {n.get('city')}  \${n.get('price_per_hour')}/h  disk={n.get('disk_gb')}  dl={n.get('download_mbps')}Mbps\")
"
plan

if [[ "$ADMIT" -ne 1 ]]; then
  echo "Stopped. No pod was rented."
  echo "Re-run with --admit when you want the H100 to start billing."
  exit 0
fi

echo "=== ADMITTED $(date -Is) smoke=$SMOKE peek=$PEEK keep=$KEEP ==="
cleanup() {
  local rc=$?
  echo "e2e cleanup rc=$rc keep=$KEEP" >&2
  if [[ "$KEEP" -eq 1 ]]; then
    echo "pod left running: $POD_NAME" >&2
    return
  fi
  "$DIR/lium_fetch.sh" || true
  "$DIR/lium_rm.sh" --force || true
}
trap cleanup EXIT

"$DIR/lium_up.sh"
RUN_ARGS=()
[[ "$SMOKE" -eq 1 ]] && RUN_ARGS+=(--smoke)
[[ "$PEEK" -eq 1 ]] && RUN_ARGS+=(--peek)
"$DIR/lium_run.sh" "${RUN_ARGS[@]+"${RUN_ARGS[@]}"}"

if [[ "$NO_WAIT" -eq 1 ]]; then
  echo "detached. watch: $DIR/lium_status.sh"
  trap - EXIT
  exit 0
fi

# Leave 20 minutes for fetch+rm before ttl.
WAIT_SEC=32400
if [[ "$SMOKE" -eq 1 || "$PEEK" -eq 1 ]]; then
  WAIT_SEC=5400
fi
echo "=== waiting up to ${WAIT_SEC}s for $REMOTE_DONE ==="
START=$(date +%s)
while true; do
  if lium exec "$POD_NAME" "test -f $REMOTE_DONE"; then
    echo "DONE present"
    lium exec "$POD_NAME" "cat $REMOTE_DONE" || true
    break
  fi
  NOW=$(date +%s)
  if (( NOW - START > WAIT_SEC )); then
    echo "wait timed out; fetching whatever exists" >&2
    break
  fi
  sleep 90
  "$DIR/lium_status.sh" || true
done

"$DIR/lium_fetch.sh"
if [[ "$KEEP" -eq 1 ]]; then
  trap - EXIT
  echo "kept pod $POD_NAME"
  exit 0
fi
"$DIR/lium_rm.sh"
trap - EXIT
echo "e2e finished. artifacts in $LOCAL_OUT"
