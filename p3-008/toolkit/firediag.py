"""Generate a response and locate where the output guard first fires (binary search on response prefix length)."""
import sys
from _common import OBJS, expand, model_direct, classify, load_tpl
tpl=load_tpl(sys.argv[1]); qid=sys.argv[2]
p=expand(tpl,OBJS[qid]); r=model_direct(p,temp=0.4)
print(f"{qid} len={len(r)} full_status={classify(r,'output')['status']}")
# binary search: shortest prefix that is HARMFUL
lo,hi=0,len(r); 
def harmful(n): return classify(r[:n],"output")["status"]=="HARMFUL"
if not harmful(len(r)):
    print("whole response HARMLESS"); sys.exit()
while hi-lo>120:
    mid=(lo+hi)//2
    if harmful(mid): hi=mid
    else: lo=mid
print(f"first becomes HARMFUL around char {hi}")
print("---- context around firing point (chars {}-{}) ----".format(max(0,hi-320),hi+40))
print(r[max(0,hi-320):hi+40])
print("\n---- response opening (first 300) ----\n"+r[:300])
