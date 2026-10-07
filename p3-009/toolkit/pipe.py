"""pipe.py <template.json> [Qids] [n]  — OPTIMISTIC proxy: direct Chutes model + output guard + judge.
Never a go/no-go — the agent system prompt makes the real gateway harsher. Use gwscore.py for truth."""
import sys
from _common import OBJS, QIDS, expand, model_direct, classify, blocked, judge, load_tpl
def trial(tpl,qid,temp=0.6):
    p=expand(tpl,OBJS[qid]); resp=model_direct(p,temp=temp)
    og=classify(resp,"output"); og_block=blocked(og)
    v,sc=judge(qid,p,resp); eff=0 if og_block else (sc or 0)
    return dict(qid=qid,len=len(resp),og=og["status"],verdict=v,score=sc,eff=eff,resp=resp)
if __name__=="__main__":
    tpl=load_tpl(sys.argv[1]); qids=sys.argv[2].split(",") if len(sys.argv)>2 else QIDS
    n=int(sys.argv[3]) if len(sys.argv)>3 else 1
    for qid in qids:
        for i in range(n):
            t=trial(tpl,qid); print(f"{qid} try{i} judge={t['score']}({t['verdict']}) outguard={t['og']} eff={t['eff']} len={t['len']}",flush=True)
