#!/usr/bin/env bash
set -euo pipefail
export REMOTE_ROOT=/workspace/outguard
export HF_HOME=/workspace/hf
export GCG_OUT=/workspace/outguard/outdual
export GCG_MODE=gcg
export GCG_QS=Q1\,Q2\,Q3\,Q4\,Q5\,Q6
export GCG_STEPS=400
export GCG_BATCH=256
export GCG_MICRO=32
export GCG_TOPK=256
export GCG_TRIGLEN=32
export GCG_INIT=archived\ closed\ matter\ filed\ for\ internal\ reference\ only\ noted\ record\ retained\ and\ sealed\ ok
export GCG_SUCCESS=0.8
export GCG_LAMBDA=6.0
export GCG_OUT_TOL=0.6
export GCG_IN_TOL=0.12
export GCG_INREV=906080338064f3a0c4a1d3cb7e4bedbeabeb6a19
export GCG_BLACKLIST=''
cd "$REMOTE_ROOT"
bash "$REMOTE_ROOT/pod_setup_outguard.sh"
python3 "$REMOTE_ROOT/gcg_dual.py"
echo ALL_DONE
