#!/usr/bin/env bash
# Rent a Secure 1x H100 80GB. Does not start GCG.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$DIR/env.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: $0
  List Secure ${GPU} nodes, pick one, rent as ${POD_NAME}.
  Writes ${LOCAL_OUT}/pod.json and node.json.
  TTL=${TTL} BUDGET=\$${BUDGET}. Billing starts at deploy.
EOF
  exit 0
fi

if [[ -f "$LOCAL_OUT/pod.json" ]]; then
  echo "pod.json already exists:" >&2
  cat "$LOCAL_OUT/pod.json" >&2
  echo "Refuse to double-rent. Remove $LOCAL_OUT/pod.json or run lium_rm.sh first." >&2
  exit 2
fi

echo "=== whoami / balance / ssh-keys ==="
lium whoami
lium balance
lium ssh-keys sync || true

echo "=== listing ${TIER} 1x ${GPU} >=${MIN_VRAM}GB VRAM ${COUNTRY} <=\$${MAX_PRICE}/h ==="
LS_JSON="$(lium ls --gpu "$GPU" --count 1 --min-vram "$MIN_VRAM" --tier "$TIER" --country "$COUNTRY" --max-price "$MAX_PRICE" --format json)"
if [[ -z "$LS_JSON" || "$LS_JSON" == "[]" ]]; then
  echo "no US nodes; retrying without country" >&2
  LS_JSON="$(lium ls --gpu "$GPU" --count 1 --min-vram "$MIN_VRAM" --tier "$TIER" --max-price "$MAX_PRICE" --format json)"
fi
echo "$LS_JSON" > "$LOCAL_OUT/ls.json"
HUID="$(python3 "$DIR/pick_node.py" <<<"$LS_JSON")"
echo "renting node $HUID as $POD_NAME"

pod_alive() {
  lium ps --filter "name=$POD_NAME" --format json 2>/dev/null | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
if not raw or raw in ("[]","null"):
    sys.exit(1)
d=json.loads(raw)
sys.exit(0 if d else 1)'
}

set +e
UP_JSON="$(lium up "$HUID" \
  --name "$POD_NAME" \
  --count 1 \
  --ttl "$TTL" \
  --budget "$BUDGET" \
  --timeout "$UP_TIMEOUT" \
  --template_id "$TEMPLATE_ID" \
  --verify-gpus \
  --strict-gpus \
  --yes \
  --json 2>"$LOCAL_OUT/up.err")"
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  echo "up with template exited $RC" >&2
  cat "$LOCAL_OUT/up.err" >&2 || true
  if pod_alive; then
    echo "pod $POD_NAME already exists — not renting a second one" >&2
    UP_JSON="$(lium ps --filter "name=$POD_NAME" --format json)"
  else
    echo "retrying without template_id" >&2
    UP_JSON="$(lium up "$HUID" \
      --name "$POD_NAME" \
      --count 1 \
      --ttl "$TTL" \
      --budget "$BUDGET" \
      --timeout "$UP_TIMEOUT" \
      --verify-gpus \
      --strict-gpus \
      --yes \
      --json)"
  fi
fi
echo "$UP_JSON" > "$LOCAL_OUT/up.json"
python3 - <<PY
import json, pathlib
p = pathlib.Path("$LOCAL_OUT")
raw = (p/"up.json").read_text()
pod = json.loads(raw)
if isinstance(pod, list):
    pod = pod[0]
rec = {
    "name": pod.get("name") or "$POD_NAME",
    "huid": pod.get("huid") or pod.get("id"),
    "id": pod.get("id"),
    "status": pod.get("status"),
    "node": "$HUID",
    "ttl": "$TTL",
    "budget": float("$BUDGET"),
    "template_id": "$TEMPLATE_ID",
}
(p/"pod.json").write_text(json.dumps(rec, indent=2))
print(json.dumps(rec, indent=2))
PY

echo "=== verify gpu ==="
lium exec "$POD_NAME" "nvidia-smi"
echo "pod $POD_NAME is billing. TTL $TTL / budget \$$BUDGET."
