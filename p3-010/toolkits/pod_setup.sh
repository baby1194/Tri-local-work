#!/usr/bin/env bash
# Runs ON the H100 pod. Installs transformers 5.x and downloads Qwen/Qwen3.8-27B.
set -euo pipefail

REMOTE_ROOT="${REMOTE_ROOT:-/workspace/p3010}"
REMOTE_HF="${REMOTE_HF:-/workspace/hf}"
REMOTE_OUT="${REMOTE_OUT:-$REMOTE_ROOT/out}"
MODEL="${MODEL:-Qwen/Qwen3.8-27B}"

export HF_HOME="$REMOTE_HF"
export HUGGINGFACE_HUB_CACHE="$REMOTE_HF/hub"
export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_XET_HIGH_PERFORMANCE=1
export PIP_CACHE_DIR=/workspace/pip
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$REMOTE_HF" "$REMOTE_OUT" "$PIP_CACHE_DIR"

echo "=== pod_setup $(date -Is) ==="
nvidia-smi
python3 - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.cuda.is_available(),
      torch.cuda.get_device_name(0) if torch.cuda.is_available() else "cpu")
if torch.cuda.is_available():
    print("vram_gb", round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 1))
PY

python3 -m pip install -U pip wheel
python3 -m pip install -U -r "$REMOTE_ROOT/toolkits/requirements.txt"
# Qwen3.8 lives in transformers 5.8.dev (config.json transformers_version).
python3 -m pip install -U "git+https://github.com/huggingface/transformers.git"

python3 - <<'PY'
import transformers
print("transformers", transformers.__version__)
from transformers import AutoConfig
c = AutoConfig.from_pretrained("Qwen/Qwen3.8-27B", trust_remote_code=True)
print("architectures", getattr(c, "architectures", None), "model_type", getattr(c, "model_type", None))
PY

echo "=== download $MODEL ==="
hf download "$MODEL" --local-dir "$REMOTE_HF/Qwen3.8-27B"
echo "=== pod_setup done $(date -Is) ==="
ls -lh "$REMOTE_HF/Qwen3.8-27B" | head
df -h /workspace
