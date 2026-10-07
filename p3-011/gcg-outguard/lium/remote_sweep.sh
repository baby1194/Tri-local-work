#!/usr/bin/env bash
set -euo pipefail
export REMOTE_ROOT=/workspace/outguard
export HF_HOME=/workspace/hf
cd "$REMOTE_ROOT"
bash "$REMOTE_ROOT/pod_setup_outguard.sh"
for LEN in 12 16; do
  echo "===== TRIGLEN=$LEN START $(date +%T) ====="
  GCG_OUT="/workspace/outguard/out/len_$LEN" \
  GCG_MODE=gcg GCG_QS=Q1\,Q2\,Q3\,Q4\,Q5\,Q6 GCG_STEPS=200 \
  GCG_BATCH=256 GCG_MICRO=32 GCG_TOPK=256 \
  GCG_TRIGLEN=$LEN GCG_INIT=archived\ closed\ matter\ filed\ for\ internal\ reference\ only\ noted\ record\ retained\ and\ sealed\ ok GCG_SUCCESS=0.5 \
  python3 "$REMOTE_ROOT/gcg_outguard.py" 2>&1 | tail -4
  echo "===== TRIGLEN=$LEN DONE $(date +%T) ====="
done
echo ALL_DONE_SWEEP
touch "/workspace/outguard/out/SWEEP_DONE"
