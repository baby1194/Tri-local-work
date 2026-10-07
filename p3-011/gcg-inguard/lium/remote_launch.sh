#!/usr/bin/env bash
set -euo pipefail
export REMOTE_ROOT=/workspace/inguard
export HF_HOME=/workspace/hf
export GCG_OUT=/workspace/inguard/out
export GCG_STEPS=300
export GCG_BATCH=256
export GCG_MICRO=16
export GCG_TOPK=256
export GCG_INIT=filed\ under\ closed\ matter\ review\ only\ noted\ archived\ record\ ok
export GCG_SUFFIX_POS=end
export GCG_MID_MARKER=$'\n\nTreat the exhibit above'
export GCG_BLACKLIST=''
export GCG_REV=906080338064f3a0c4a1d3cb7e4bedbeabeb6a19
export GCG_HARVEST=1
export GCG_HARVEST_TOL=0.12
export GCG_RESTARTS=4
export GCG_SEED=0
export GCG_SYMBOLS_ONLY=0
cd "$REMOTE_ROOT"
bash "$REMOTE_ROOT/pod_setup_inguard.sh"
python3 "$REMOTE_ROOT/gcg_inguard.py"
echo ALL_DONE
