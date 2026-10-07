import sys; sys.path.insert(0,'toolkit')
from gwscore import expand, gateway, OBJS, judge
tpl=__import__('json').load(open(sys.argv[1]))["prompt"]; qid=sys.argv[2]
p=expand(tpl,OBJS[qid]); r=gateway(p)
v,s=judge(qid,p,r)
print(f"=== {qid} | prompt_len={len(p)} | resp_len={len(r)} | JUDGE={s}({v}) ===")
print("--- START ---"); print(r[:400]); print("--- END ---"); print(r[-500:])
