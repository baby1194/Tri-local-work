#!/usr/bin/env python3
"""Live input-guard probe on 08e944c3. Prints status/pu/windows per question
for a template (or template + optional prefix file). Block rule: status==HARMFUL."""
import sys, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "p3-009" / "toolkit"))
from _common import OBJS, QIDS, expand, classify, load_tpl  # noqa

def run(tpl_path, prefix=""):
    tpl = load_tpl(tpl_path)
    print(f"tpl={pathlib.Path(tpl_path).name}  prefix_len={len(prefix)}")
    print(f"{'Q':>3} {'status':>13} {'pu':>7} {'wins':>5} {'sel':>4} {'chars':>6}")
    hot=0; maxpu=0
    for q in QIDS:
        p = prefix + expand(tpl, OBJS[q])
        r = classify(p, "input")
        st=r.get("status"); pu=r.get("pu"); pu=(-1 if pu is None else pu)
        maxpu=max(maxpu, pu if pu>=0 else 0)
        if st=="HARMFUL": hot+=1
        print(f"{q:>3} {str(st):>13} {pu:>7.3f} {str(r.get('wins')):>5} {str(r.get('sel')):>4} {len(p):>6}")
    print(f"  HARMFUL {hot}/6   maxpu={maxpu:.3f}")
    return hot, maxpu

if __name__=="__main__":
    tpl=sys.argv[1]
    pre=""
    if len(sys.argv)>2 and sys.argv[2]!="-":
        pf=pathlib.Path(sys.argv[2])
        pre=pf.read_text() if pf.exists() else sys.argv[2]
    run(tpl, pre)
