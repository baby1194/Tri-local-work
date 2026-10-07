import sys; sys.path.insert(0,'toolkit')
from pipe import expand, model, OBJS, out_guard_unsafe, judge
tpl=__import__('json').load(open(sys.argv[1]))["prompt"]
qid=sys.argv[2]
p=expand(tpl,OBJS[qid]); r=model(p,temp=0.6,think=False)
lbl,pu=out_guard_unsafe(r); v,s=judge(qid,p,r)
print(f"=== {qid} judge={s}({v}) outguard={lbl}({pu}) len={len(r)} ===")
print(r)
