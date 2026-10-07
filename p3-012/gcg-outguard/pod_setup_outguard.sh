#!/usr/bin/env bash
# Runs ON the GPU pod. Light setup for the 0.8B OUTPUT-guard GCG (no 27B).
set -euo pipefail
REMOTE_ROOT="${REMOTE_ROOT:-/workspace/outguard}"
export HF_HOME="${HF_HOME:-/workspace/hf}"
export HUGGINGFACE_HUB_CACHE="$HF_HOME/hub"
export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_HUB_DISABLE_XET=1
export PIP_CACHE_DIR=/workspace/pip
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HF_HOME" "$PIP_CACHE_DIR"

echo "=== pod_setup_outguard $(date -Is) ==="
nvidia-smi || true

python3 -m pip install -U pip wheel >/dev/null
if ! python3 -c "import torch" 2>/dev/null; then
  echo "torch missing; installing default cuda wheel"
  python3 -m pip install torch
fi
python3 - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.cuda.is_available(),
      torch.cuda.get_device_name(0) if torch.cuda.is_available() else "cpu")
PY
# transformers 5.x supports qwen3_5 (the guard arch). accelerate + hf_transfer for fast dl.
python3 -m pip install -U "transformers>=5.5" accelerate huggingface_hub hf_transfer
python3 -m pip install -U flash-linear-attention causal-conv1d 2>/dev/null || echo "fla/causal-conv1d not installed; using reference kernels"

python3 - <<'PY'
import transformers; print("transformers", transformers.__version__)
PY

echo "=== prefetch OUTPUT-guard weights (backbone + token_head.pt, main=1c7f4ff35091) ==="
hf download astroware/Halo0.8B-outputguard-v1 >/dev/null
echo "=== pod_setup_outguard done $(date -Is) ==="
