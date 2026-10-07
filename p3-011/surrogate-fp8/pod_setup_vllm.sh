#!/usr/bin/env bash
# Runs ON the GPU pod. Installs vLLM + downloads the EXACT live checkpoint, then serves it.
set -euo pipefail
export HF_HOME="${HF_HOME:-/workspace/hf}"
export HF_HUB_ENABLE_HF_TRANSFER=1
export PATH="$HOME/.local/bin:$PATH"
MODEL=Qwen/Qwen3.8-27B-FP8
REV=017b9c7af6b5689d5dd426a76e0bc077eb5ca20a
mkdir -p "$HF_HOME" /workspace/out
echo "=== pod_setup_vllm $(date -Is) ==="; nvidia-smi || true
python3 -m pip install -U pip >/dev/null
# recent vLLM (must support qwen3.8 hybrid arch). Try latest; fall back handled by caller.
python3 -m pip install -U vllm huggingface_hub hf_transfer 2>&1 | tail -5
python3 -c "import vllm; print('vllm', vllm.__version__)"
echo "=== download $MODEL @ $REV (31GB) ==="
hf download "$MODEL" --revision "$REV" --local-dir /workspace/model 2>&1 | tail -3
echo "=== serve (vLLM OpenAI API :8000, served-model-name Qwen/Qwen3.8-27B-TEE) ==="
# engine args mirror the chute (minus tee/mtp-speculative which don't change outputs); modest ctx to fit.
nohup vllm serve /workspace/model \
  --served-model-name Qwen/Qwen3.8-27B-TEE \
  --enable-auto-tool-choice --tool-call-parser qwen3_coder --reasoning-parser qwen3 \
  --max-model-len 16384 --max-num-seqs 8 --tensor-parallel-size 1 \
  --host 0.0.0.0 --port 8000 --api-key sk-local \
  > /workspace/out/vllm.log 2>&1 &
echo "vllm serving (PID $!), log /workspace/out/vllm.log"
echo "=== wait for readiness ==="
for i in $(seq 1 90); do
  if curl -s http://localhost:8000/v1/models 2>/dev/null | grep -q Qwen3.8-27B-TEE; then echo "VLLM_READY"; break; fi
  sleep 10
done
curl -s http://localhost:8000/v1/models 2>/dev/null | head -c 400; echo
