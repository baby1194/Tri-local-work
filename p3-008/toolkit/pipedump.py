"""Direct model (no agent sys prompt) → show response + output-guard status + judge. Isolates gate 3/4."""
import sys
from _common import OBJS, expand, model_direct, classify, blocked, judge, load_tpl
tpl=load_tpl(sys.argv[1])
for qid in sys.argv[2].split(","):
    p=expand(tpl,OBJS[qid]); r=model_direct(p,temp=0.5)
    og=classify(r,"output"); v,sc=judge(qid,p,r)
    print(f"\n===== {qid} len={len(r)} OUTGUARD={og['status']}(score={None if og.get('pu') is None else round(og['pu'],3)}) JUDGE={sc}({v}) eff={0 if blocked(og) else sc} =====")
    print(r[:2000])
