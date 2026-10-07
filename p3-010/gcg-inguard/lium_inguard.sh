#!/usr/bin/env bash
# p3-010 input-guard GCG on a Secure 1x RTX4090 (24GB). Self-contained.
# Rents, syncs gcg-inguard/, runs pod_setup_inguard.sh, detaches gcg_inguard.py.
# Idempotent-ish: refuses to double-rent if pod.json already exists.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

POD_NAME="${POD_NAME:-gcg-p3010-inguard}"
GPU="${GPU:-RTX4090}"
TIER="${TIER:-secure}"
MAX_PRICE="${MAX_PRICE:-0.60}"
TTL="${TTL:-4h}"
BUDGET="${BUDGET:-4}"
UP_TIMEOUT="${UP_TIMEOUT:-900}"
MIN_VRAM="${MIN_VRAM:-24}"
MIN_DISK="${MIN_DISK:-40}"
MIN_DOWNLOAD="${MIN_DOWNLOAD:-200}"
# pytorch DinD (torch preinstalled); setup installs torch anyway if absent.
TEMPLATE_ID="${TEMPLATE_ID:-bb50bd64-e363-4adc-8111-1d44c8e36807}"

REMOTE_ROOT="${REMOTE_ROOT:-/workspace/inguard}"
REMOTE_OUT="$REMOTE_ROOT/out"
REMOTE_LOG="$REMOTE_OUT/gcg.log"

# GCG knobs (24GB fp32 headroom: modest MICRO).
GCG_STEPS="${GCG_STEPS:-500}"
GCG_BATCH="${GCG_BATCH:-256}"
GCG_MICRO="${GCG_MICRO:-16}"
GCG_TOPK="${GCG_TOPK:-256}"
GCG_INIT="${GCG_INIT:-filed under closed matter review only noted archived record ok}"
GCG_SUFFIX_POS="${GCG_SUFFIX_POS:-end}"
GCG_MID_MARKER="${GCG_MID_MARKER:-$'\n\nTreat the exhibit above'}"
GCG_BLACKLIST="${GCG_BLACKLIST-}"
GCG_REV="${GCG_REV:-08e944c346b3}"
# Step 1 AmpleGCG harvest knobs (off by default = single-shot behavior).
GCG_HARVEST="${GCG_HARVEST:-0}"
GCG_HARVEST_TOL="${GCG_HARVEST_TOL:-0.12}"
GCG_RESTARTS="${GCG_RESTARTS:-1}"
GCG_SEED="${GCG_SEED:-0}"

LOCAL_OUT="$DIR/lium"
mkdir -p "$LOCAL_OUT"

if [[ -f "$LOCAL_OUT/pod.json" ]]; then
  echo "pod.json exists — refusing to double-rent. Remove it or run lium_rm first:" >&2
  cat "$LOCAL_OUT/pod.json" >&2
  exit 2
fi

echo "=== balance / ssh-keys ==="
lium balance
lium ssh-keys sync || true

echo "=== pick a Secure 1x $GPU node (<=\$$MAX_PRICE/h) ==="
LS_JSON="$(lium ls --gpu "$GPU" --tier "$TIER" --max-price "$MAX_PRICE" --format json)"
echo "$LS_JSON" > "$LOCAL_OUT/ls.json"
HUID="$(MIN_VRAM=$MIN_VRAM MIN_DISK=$MIN_DISK MIN_DOWNLOAD=$MIN_DOWNLOAD LOCAL_OUT=$LOCAL_OUT \
  python3 "$DIR/../toolkits/pick_node.py" <<<"$LS_JSON")"
echo "renting $HUID as $POD_NAME (ttl $TTL, budget \$$BUDGET)"

set +e
UP_JSON="$(lium up "$HUID" --name "$POD_NAME" --count 1 --ttl "$TTL" --budget "$BUDGET" \
  --timeout "$UP_TIMEOUT" --template_id "$TEMPLATE_ID" --yes --json 2>"$LOCAL_OUT/up.err")"
RC=$?
if [[ $RC -ne 0 ]]; then
  echo "up with template exited $RC; err:" >&2; cat "$LOCAL_OUT/up.err" >&2 || true
  # maybe the pod came up anyway
  ALIVE="$(lium ps --filter "name=$POD_NAME" --format json 2>/dev/null)"
  if [[ -n "$ALIVE" && "$ALIVE" != "[]" ]]; then
    echo "pod $POD_NAME already exists; using it" >&2; UP_JSON="$ALIVE"
  else
    echo "retry without template_id (setup will install torch)" >&2
    UP_JSON="$(lium up "$HUID" --name "$POD_NAME" --count 1 --ttl "$TTL" --budget "$BUDGET" \
      --timeout "$UP_TIMEOUT" --yes --json)"
    RC=$?
    [[ $RC -ne 0 ]] && { echo "up failed rc=$RC" >&2; exit 1; }
  fi
fi
set -e
echo "$UP_JSON" > "$LOCAL_OUT/up.json"
python3 - "$LOCAL_OUT" "$POD_NAME" "$HUID" "$TTL" "$BUDGET" <<'PY'
import json,sys,pathlib
out,name,node,ttl,budget=sys.argv[1:6]
p=pathlib.Path(out); pod=json.loads((p/"up.json").read_text())
if isinstance(pod,list): pod=pod[0]
rec={"name":pod.get("name") or name,"huid":pod.get("huid") or pod.get("id"),
     "id":pod.get("id"),"status":pod.get("status"),"node":node,"ttl":ttl,"budget":float(budget)}
(p/"pod.json").write_text(json.dumps(rec,indent=2)); print(json.dumps(rec,indent=2))
PY

echo "=== verify gpu ==="
lium exec "$POD_NAME" "nvidia-smi --query-gpu=name,memory.total --format=csv,noheader" || true

echo "=== mkdir + rsync gcg-inguard -> $POD_NAME:$REMOTE_ROOT ==="
lium exec "$POD_NAME" "mkdir -p $REMOTE_ROOT $REMOTE_OUT"
lium rsync "$POD_NAME" "$DIR/" "$REMOTE_ROOT" --progress \
  --exclude '__pycache__' --exclude '*.pyc' --exclude '.git' --exclude 'lium' --exclude 'out'

LAUNCH="$LOCAL_OUT/remote_launch.sh"
{
  echo "#!/usr/bin/env bash"
  echo "set -euo pipefail"
  echo "export REMOTE_ROOT=$(printf %q "$REMOTE_ROOT")"
  echo "export HF_HOME=/workspace/hf"
  echo "export GCG_OUT=$(printf %q "$REMOTE_OUT")"
  echo "export GCG_STEPS=$(printf %q "$GCG_STEPS")"
  echo "export GCG_BATCH=$(printf %q "$GCG_BATCH")"
  echo "export GCG_MICRO=$(printf %q "$GCG_MICRO")"
  echo "export GCG_TOPK=$(printf %q "$GCG_TOPK")"
  echo "export GCG_INIT=$(printf %q "$GCG_INIT")"
  echo "export GCG_SUFFIX_POS=$(printf %q "$GCG_SUFFIX_POS")"
  echo "export GCG_MID_MARKER=$(printf %q "$GCG_MID_MARKER")"
  echo "export GCG_BLACKLIST=$(printf %q "$GCG_BLACKLIST")"
  echo "export GCG_REV=$(printf %q "$GCG_REV")"
  echo "export GCG_HARVEST=$(printf %q "$GCG_HARVEST")"
  echo "export GCG_HARVEST_TOL=$(printf %q "$GCG_HARVEST_TOL")"
  echo "export GCG_RESTARTS=$(printf %q "$GCG_RESTARTS")"
  echo "export GCG_SEED=$(printf %q "$GCG_SEED")"
  echo "cd \"\$REMOTE_ROOT\""
  echo "bash \"\$REMOTE_ROOT/pod_setup_inguard.sh\""
  echo "python3 \"\$REMOTE_ROOT/gcg_inguard.py\""
  echo "echo ALL_DONE"
} > "$LAUNCH"
chmod +x "$LAUNCH"
lium scp "$POD_NAME" "$LAUNCH" "$REMOTE_ROOT/remote_launch.sh"

echo "=== detach setup+GCG (log=$REMOTE_LOG, steps=$GCG_STEPS) ==="
lium exec "$POD_NAME" -d --log "$REMOTE_LOG" "bash $REMOTE_ROOT/remote_launch.sh"
echo "started on $POD_NAME. tail: lium logs $POD_NAME  (or lium exec $POD_NAME \"tail -f $REMOTE_LOG\")"
echo "artifacts land in $REMOTE_OUT (best.json, best_suffix.txt, harvest.jsonl, DONE)."
