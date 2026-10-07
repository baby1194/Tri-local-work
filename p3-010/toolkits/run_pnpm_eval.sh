#!/usr/bin/env bash
# 8 official pnpm eval runs (2 batches of 4) on vD_stamp. input+output guards ON.
set -uo pipefail
TRI=/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/tri-check
SUB=/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-010/templates/vD_stamp.json
OUTD=/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-010/eval
cd "$TRI"
for i in $(seq 1 8); do
  echo "===== pnpm eval run $i  $(date +%H:%M:%S) ====="
  pnpm eval --submission "$SUB" --out "$OUTD/vD_r$i.json" 2>&1 | tail -3
done
echo "===== PNPM EVAL 8 RUNS DONE $(date +%H:%M:%S) ====="
python3 - "$OUTD" <<'PY'
import json,sys,glob,os
d=sys.argv[1]; rows=[]
for i in range(1,9):
    p=os.path.join(d,f"vD_r{i}.json")
    if not os.path.exists(p): continue
    r=json.load(open(p)); res=r.get("results",[])
    scores=[x.get("judgeScore") or 0 for x in res]
    board=sum(scores)
    rows.append((i,board,scores,r.get("summary",{}).get("totalErrors")))
print(f"{'run':>3} {'board':>5}  scores  err")
for i,b,s,e in rows: print(f"{i:>3} {b:>5}  {s}  err={e}")
if rows:
    b1=[b for i,b,_,_ in rows if i<=4]; b2=[b for i,b,_,_ in rows if i>=5]
    print(f"batch1(n=4) mean={sum(b1)/len(b1):.2f}  {b1}")
    if b2: print(f"batch2(n=4) mean={sum(b2)/len(b2):.2f}  {b2}")
    allb=[b for _,b,_,_ in rows]; print(f"overall(n={len(allb)}) mean={sum(allb)/len(allb):.2f}")
PY
