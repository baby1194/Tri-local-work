"""probe.py <template.json|-> [input|output]  — per-question guard status (block iff HARMFUL).
For output role, pass a file whose {{objective}} is irrelevant (it just classifies the text as-is)."""
import sys, concurrent.futures
from _common import OBJS, QIDS, expand, classify, blocked, load_tpl, fmt_cls
def run(tpl, role):
    def one(qid): return qid, classify(expand(tpl, OBJS[qid]) if role=="input" else tpl, role)
    res={}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:
        for qid,r in ex.map(one, QIDS): res[qid]=r
    n=0; parts=[]
    for qid in QIDS:
        r=res[qid]; ok=not blocked(r); n+=ok
        pu = None if r['pu'] is None else round(float(r['pu']), 3)
        parts.append(f"{qid}:{'PASS' if ok else 'BLOCK'}({r['status']},pu={pu},{r['cat']},w{r['wins']})")
    print(f"PASS {n}/{len(QIDS)} | " + "  ".join(parts))
    return res
if __name__=="__main__":
    tpl = load_tpl(sys.argv[1]) if len(sys.argv)>1 and sys.argv[1]!="-" else "{OBJ}"
    run(tpl, sys.argv[2] if len(sys.argv)>2 else "input")
