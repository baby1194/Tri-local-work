#!/usr/bin/env bash
# Upload toolkits, set up the pod, detach GCG.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$DIR/env.sh"

SMOKE=0
PEEK=0
SKIP_SETUP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --smoke) SMOKE=1; GCG_STEPS="${GCG_STEPS_SMOKE:-5}"; TTL_NOTE="smoke 5 steps" ;;
    --peek) PEEK=1 ;;
    --skip-setup) SKIP_SETUP=1 ;;
    -h|--help)
      echo "Usage: $0 [--smoke] [--peek] [--skip-setup]"
      echo "  rsync toolkits, pod_setup.sh, then detach gcg_a021_stamp.py"
      exit 0
      ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ ! -f "$LOCAL_OUT/pod.json" ]]; then
  echo "no $LOCAL_OUT/pod.json — run lium_up.sh first" >&2
  exit 2
fi

echo "=== mkdir $REMOTE_ROOT on $POD_NAME ==="
lium exec "$POD_NAME" "mkdir -p $REMOTE_ROOT/toolkits $REMOTE_OUT"

echo "=== rsync $TK -> $POD_NAME:$REMOTE_ROOT/toolkits ==="
lium rsync "$POD_NAME" "$TK" "$REMOTE_ROOT/toolkits" --progress \
  --exclude '__pycache__' --exclude '*.pyc' --exclude '.git'
if [[ -f "$TPL" ]]; then
  lium scp "$POD_NAME" "$TPL" "$REMOTE_ROOT/a021_debrief.json"
fi

LAUNCH="$LOCAL_OUT/remote_launch.sh"
{
  echo "#!/usr/bin/env bash"
  echo "set -euo pipefail"
  echo "export REMOTE_ROOT=$(printf %q "$REMOTE_ROOT")"
  echo "export REMOTE_HF=$(printf %q "$REMOTE_HF")"
  echo "export REMOTE_OUT=$(printf %q "$REMOTE_OUT")"
  echo "export MODEL=$(printf %q "$MODEL")"
  echo "export HF_HOME=$(printf %q "$REMOTE_HF")"
  echo "export HUGGINGFACE_HUB_CACHE=$(printf %q "$REMOTE_HF/hub")"
  echo "export HF_HUB_ENABLE_HF_TRANSFER=1"
  echo "export HF_XET_HIGH_PERFORMANCE=1"
  echo "export GCG_OUT=$(printf %q "$REMOTE_OUT")"
  echo "export GCG_LOCAL_DIR=$(printf %q "$REMOTE_HF/Qwen3.8-27B")"
  echo "export GCG_MODEL=$(printf %q "$MODEL")"
  echo "export GCG_STEPS=$(printf %q "$GCG_STEPS")"
  echo "export GCG_BATCH=$(printf %q "$GCG_BATCH")"
  echo "export GCG_MICRO=$(printf %q "$GCG_MICRO")"
  echo "export GCG_TOPK=$(printf %q "$GCG_TOPK")"
  if [[ "$PEEK" -eq 1 ]]; then
    echo "export GCG_PEEK_ONLY=1"
  fi
  echo "mkdir -p \"\$REMOTE_OUT\""
  if [[ "$SKIP_SETUP" -eq 0 ]]; then
    echo "bash \"\$REMOTE_ROOT/toolkits/pod_setup.sh\""
  fi
  echo "python3 \"\$REMOTE_ROOT/toolkits/gcg_a021_stamp.py\""
} > "$LAUNCH"
chmod +x "$LAUNCH"
lium scp "$POD_NAME" "$LAUNCH" "$REMOTE_ROOT/remote_launch.sh"

echo "=== detach setup+GCG  log=$REMOTE_LOG  steps=$GCG_STEPS ==="
lium exec "$POD_NAME" -d --log "$REMOTE_LOG" "bash $REMOTE_ROOT/remote_launch.sh"
echo "started. follow with: $DIR/lium_status.sh"
echo "artifacts land in $REMOTE_OUT on the pod."
