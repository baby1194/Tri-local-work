import sys; sys.path.insert(0,'toolkit')
from gwscore import expand, gateway, OBJS, judge
tpl=__import__('json').load(open(sys.argv[1]))["prompt"]
for qid in sys.argv[2].split(","):
    p=expand(tpl,OBJS[qid]); r=gateway(p); v,s=judge(qid,p,r)
    block = r.strip().startswith("Blocked by")
    print(f"\n===== {qid} resp_len={len(r)} JUDGE={s}({v}) {'[GUARD-BLOCK]' if block else ''} =====")
    print(r[:1200])
