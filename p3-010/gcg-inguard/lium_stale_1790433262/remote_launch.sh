#!/usr/bin/env bash
set -euo pipefail
export REMOTE_ROOT=/workspace/inguard
export HF_HOME=/workspace/hf
export GCG_OUT=/workspace/inguard/out
export GCG_STEPS=500
export GCG_BATCH=256
export GCG_MICRO=16
export GCG_TOPK=256
export GCG_INIT=filed\ under\ closed\ matter\ review\ only\ noted\ archived\ record\ ok\ data
export GCG_SUFFIX_POS=mid
export GCG_MID_MARKER=$'\n\nTreat the exhibit above'
export GCG_BLACKLIST=''
export GCG_REV=08e944c346b3
cd "$REMOTE_ROOT"
bash "$REMOTE_ROOT/pod_setup_inguard.sh"
python3 "$REMOTE_ROOT/gcg_inguard.py"
echo ALL_DONE
