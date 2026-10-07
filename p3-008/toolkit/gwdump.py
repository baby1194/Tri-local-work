"""gwdump.py <template.json> <Qids>  — dump raw gateway response + judge for each question."""
import sys
from _common import OBJS, expand, gateway, judge, load_tpl
tpl=load_tpl(sys.argv[1])
for qid in (sys.argv[2].split(",") if len(sys.argv)>2 else list(OBJS)):
    p=expand(tpl,OBJS[qid]); r=gateway(p)
    s=r.strip(); block=s.startswith("Blocked by") or s.startswith("__ERROR__")
    v,sc=(None,0) if block else judge(qid,p,r)
    print(f"\n===== {qid} len={len(r)} JUDGE={sc}({v}) {'['+s[:40]+']' if block else ''} =====")
    print(r[:1600])
