#!/usr/bin/env bash
set -euo pipefail
export REMOTE_ROOT=/workspace/p3010
export REMOTE_HF=/workspace/hf
export REMOTE_OUT=/workspace/p3010/out
export MODEL=Qwen/Qwen3.8-27B
export HF_HOME=/workspace/hf
export HUGGINGFACE_HUB_CACHE=/workspace/hf/hub
export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_XET_HIGH_PERFORMANCE=1
export GCG_OUT=/workspace/p3010/out
export GCG_LOCAL_DIR=/workspace/hf/Qwen3.8-27B
export GCG_MODEL=Qwen/Qwen3.8-27B
export GCG_STEPS=300
export GCG_BATCH=8
export GCG_MICRO=1
export GCG_TOPK=256
mkdir -p "$REMOTE_OUT"
bash "$REMOTE_ROOT/toolkits/pod_setup.sh"
python3 "$REMOTE_ROOT/toolkits/gcg_a021_stamp.py"
