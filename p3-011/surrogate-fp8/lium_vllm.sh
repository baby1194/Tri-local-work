#!/usr/bin/env bash
# Rent an H100, sync surrogate-fp8/, install vLLM + serve the EXACT live FP8 checkpoint (detached).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD_NAME="${POD_NAME:-fp8-surrogate}"
GPU="${GPU:-H100}"; TIER="${TIER:-secure}"; MAX_PRICE="${MAX_PRICE:-3.0}"
TTL="${TTL:-3h}"; BUDGET="${BUDGET:-8}"; UP_TIMEOUT="${UP_TIMEOUT:-900}"
MIN_VRAM="${MIN_VRAM:-80}"; MIN_DISK="${MIN_DISK:-80}"; MIN_DOWNLOAD="${MIN_DOWNLOAD:-300}"
TEMPLATE_ID="${TEMPLATE_ID:-bb50bd64-e363-4adc-8111-1d44c8e36807}"
REMOTE_ROOT="/workspace/surr"; REMOTE_LOG="/workspace/out/setup.log"
LOCAL_OUT="$DIR/lium"; mkdir -p "$LOCAL_OUT"
[[ -f "$LOCAL_OUT/pod.json" ]] && { echo "pod.json exists; rm it or lium_rm first" >&2; exit 2; }
echo "=== balance ==="; lium balance; lium ssh-keys sync || true
echo "=== pick $GPU node <=\$$MAX_PRICE ==="
LS_JSON="$(lium ls --gpu "$GPU" --tier "$TIER" --max-price "$MAX_PRICE" --format json)"; echo "$LS_JSON" > "$LOCAL_OUT/ls.json"
HUID="$(MIN_VRAM=$MIN_VRAM MIN_DISK=$MIN_DISK MIN_DOWNLOAD=$MIN_DOWNLOAD LOCAL_OUT=$LOCAL_OUT python3 "$DIR/../toolkits/pick_node.py" <<<"$LS_JSON")"
echo "renting $HUID as $POD_NAME"
set +e
UP_JSON="$(lium up "$HUID" --name "$POD_NAME" --count 1 --ttl "$TTL" --budget "$BUDGET" --timeout "$UP_TIMEOUT" --template_id "$TEMPLATE_ID" --yes --json 2>"$LOCAL_OUT/up.err")"
[[ $? -ne 0 ]] && { ALIVE="$(lium ps --filter "name=$POD_NAME" --format json 2>/dev/null)"; [[ -n "$ALIVE" && "$ALIVE" != "[]" ]] && UP_JSON="$ALIVE" || UP_JSON="$(lium up "$HUID" --name "$POD_NAME" --count 1 --ttl "$TTL" --budget "$BUDGET" --timeout "$UP_TIMEOUT" --yes --json)"; }
set -e
echo "$UP_JSON" > "$LOCAL_OUT/up.json"
python3 - "$LOCAL_OUT" "$POD_NAME" "$HUID" "$TTL" "$BUDGET" <<'PY'
import json,sys,pathlib
out,name,node,ttl,budget=sys.argv[1:6]; p=pathlib.Path(out); pod=json.loads((p/"up.json").read_text())
if isinstance(pod,list): pod=pod[0]
(p/"pod.json").write_text(json.dumps({"name":pod.get("name") or name,"node":node,"ttl":ttl},indent=2)); print("pod recorded")
PY
echo "=== gpu ==="; lium exec "$POD_NAME" "nvidia-smi --query-gpu=name,memory.total --format=csv,noheader" || true
echo "=== sync + launch setup/serve (detached) ==="
lium exec "$POD_NAME" "mkdir -p $REMOTE_ROOT /workspace/out"
lium rsync "$POD_NAME" "$DIR/" "$REMOTE_ROOT" --exclude lium --exclude '__pycache__'
lium exec "$POD_NAME" -d --log "$REMOTE_LOG" "export HF_HOME=/workspace/hf; bash $REMOTE_ROOT/pod_setup_vllm.sh"
echo "started on $POD_NAME. tail: lium exec $POD_NAME \"tail -f $REMOTE_LOG\""
