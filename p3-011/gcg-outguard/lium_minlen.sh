#!/usr/bin/env bash
# p3-011 MIN-LENGTH OUTPUT-guard cooler GCG on a Secure 1x RTX4090 (24GB).
# Sweeps GCG_TRIGLEN to find the SHORTEST position-0 prefix that cools maxUSER<0.8 over ALL 6
# objectives (frame_vb.txt == vF2 body). Shorter prefix = smaller stamp-rate tax (§10.3).
# Reuses pod_setup_outguard.sh + gcg_outguard.py; detaches a sweep loop. No double-rent.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

POD_NAME="${POD_NAME:-gcg-p3011-minlen}"
GPU="${GPU:-RTX4090}"
TIER="${TIER:-secure}"
MAX_PRICE="${MAX_PRICE:-0.60}"
TTL="${TTL:-3h}"
BUDGET="${BUDGET:-3}"
UP_TIMEOUT="${UP_TIMEOUT:-900}"
MIN_VRAM="${MIN_VRAM:-24}"
MIN_DISK="${MIN_DISK:-40}"
MIN_DOWNLOAD="${MIN_DOWNLOAD:-200}"
TEMPLATE_ID="${TEMPLATE_ID:-bb50bd64-e363-4adc-8111-1d44c8e36807}"

REMOTE_ROOT="${REMOTE_ROOT:-/workspace/outguard}"
REMOTE_OUT="$REMOTE_ROOT/out"
REMOTE_LOG="$REMOTE_OUT/minlen.log"

# sweep knobs
LENS="${LENS:-12 18 24 32 44}"
GCG_QS="${GCG_QS:-Q1,Q2,Q3,Q4,Q5,Q6}"
GCG_STEPS="${GCG_STEPS:-200}"
GCG_BATCH="${GCG_BATCH:-256}"
GCG_MICRO="${GCG_MICRO:-32}"
GCG_TOPK="${GCG_TOPK:-256}"
GCG_SUCCESS="${GCG_SUCCESS:-0.6}"
# mundane cool init (repeated/truncated to each length by the script)
GCG_INIT="${GCG_INIT:-archived closed matter filed for internal reference only noted record retained and sealed ok}"

LOCAL_OUT="$DIR/lium"
mkdir -p "$LOCAL_OUT"
if [[ -f "$LOCAL_OUT/pod.json" ]]; then
  echo "pod.json exists — refusing to double-rent. Remove it or terminate the pod first:" >&2
  cat "$LOCAL_OUT/pod.json" >&2; exit 2
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
  ALIVE="$(lium ps --filter "name=$POD_NAME" --format json 2>/dev/null)"
  if [[ -n "$ALIVE" && "$ALIVE" != "[]" ]]; then
    echo "pod $POD_NAME already exists; using it" >&2; UP_JSON="$ALIVE"
  else
    echo "retry without template_id" >&2
    UP_JSON="$(lium up "$HUID" --name "$POD_NAME" --count 1 --ttl "$TTL" --budget "$BUDGET" \
      --timeout "$UP_TIMEOUT" --yes --json)"; RC=$?
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

echo "=== rsync gcg-outguard -> $POD_NAME:$REMOTE_ROOT ==="
lium exec "$POD_NAME" "mkdir -p $REMOTE_ROOT $REMOTE_OUT"
lium rsync "$POD_NAME" "$DIR/" "$REMOTE_ROOT" --progress \
  --exclude '__pycache__' --exclude '*.pyc' --exclude '.git' --exclude 'lium' --exclude 'out'

LAUNCH="$LOCAL_OUT/remote_sweep.sh"
{
  echo "#!/usr/bin/env bash"
  echo "set -euo pipefail"
  echo "export REMOTE_ROOT=$(printf %q "$REMOTE_ROOT")"
  echo "export HF_HOME=/workspace/hf"
  echo "cd \"\$REMOTE_ROOT\""
  echo "bash \"\$REMOTE_ROOT/pod_setup_outguard.sh\""
  echo "for LEN in $LENS; do"
  echo "  echo \"===== TRIGLEN=\$LEN START \$(date +%T) =====\""
  echo "  GCG_OUT=\"$REMOTE_OUT/len_\$LEN\" \\"
  echo "  GCG_MODE=gcg GCG_QS=$(printf %q "$GCG_QS") GCG_STEPS=$(printf %q "$GCG_STEPS") \\"
  echo "  GCG_BATCH=$(printf %q "$GCG_BATCH") GCG_MICRO=$(printf %q "$GCG_MICRO") GCG_TOPK=$(printf %q "$GCG_TOPK") \\"
  echo "  GCG_TRIGLEN=\$LEN GCG_INIT=$(printf %q "$GCG_INIT") GCG_SUCCESS=$(printf %q "$GCG_SUCCESS") \\"
  echo "  python3 \"\$REMOTE_ROOT/gcg_outguard.py\" 2>&1 | tail -4"
  echo "  echo \"===== TRIGLEN=\$LEN DONE \$(date +%T) =====\""
  echo "done"
  echo "echo ALL_DONE_SWEEP"
  echo "touch \"$REMOTE_OUT/SWEEP_DONE\""
} > "$LAUNCH"
chmod +x "$LAUNCH"
lium scp "$POD_NAME" "$LAUNCH" "$REMOTE_ROOT/remote_sweep.sh"

echo "=== detach sweep (log=$REMOTE_LOG) ==="
lium exec "$POD_NAME" -d --log "$REMOTE_LOG" "bash $REMOTE_ROOT/remote_sweep.sh"
echo "started sweep on $POD_NAME. tail: lium exec $POD_NAME \"tail -f $REMOTE_LOG\""
echo "artifacts per length: $REMOTE_OUT/len_<N>/best.json ; done marker: $REMOTE_OUT/SWEEP_DONE"
