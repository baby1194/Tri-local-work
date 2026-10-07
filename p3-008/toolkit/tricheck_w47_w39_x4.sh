#!/usr/bin/env bash
# Official tri-check eval (OpenClaw → Judge), w47 vs w39, 4 independent runs.
set -euo pipefail
ROOT="/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2"
OUT="$ROOT/local-work/p3-008/captures/tricheck_w47_w39"
W47="$ROOT/local-work/p3-008/templates_en/w47_shortprimer_filenote.json"
W39="$ROOT/local-work/p3-008/templates_en/w39_caseid_filenote.json"
mkdir -p "$OUT"
cd "$ROOT/tri-check"

for i in 1 2 3 4; do
  echo "===== ROUND $i/4 ====="
  pnpm eval --submission "$W47" --out "$OUT/w47_r${i}.json" > "$OUT/w47_r${i}.log" 2>&1 &
  p47=$!
  pnpm eval --submission "$W39" --out "$OUT/w39_r${i}.json" > "$OUT/w39_r${i}.log" 2>&1 &
  p39=$!
  wait "$p47"
  e47=$?
  wait "$p39"
  e39=$?
  echo "round $i exit: w47=$e47 w39=$e39"
  python3 - <<PY
import json
from pathlib import Path
out = Path("$OUT")
for name in ("w47", "w39"):
    p = out / f"{name}_r${i}.json"
    if not p.exists():
        print(f"  {name}: NO REPORT")
        continue
    d = json.loads(p.read_text())
    rows = {r["id"]: r for r in d.get("results", [])}
    bits = []
    tot = 0
    for q in ("Q1","Q2","Q3","Q4","Q5","Q6"):
        r = rows.get(q, {})
        sc = r.get("judgeScore", 0) or 0
        err = r.get("error")
        tag = "ERR" if err else ("JB" if r.get("successfulJailbreak") else (r.get("judgeVerdict") or "?"))
        bits.append(f"{q}={sc}({tag})")
        tot += sc
    print(f"  {name}  {tot}/12  " + "  ".join(bits))
PY
done

echo
echo "===== 4-ROUND SUMMARY ====="
python3 - <<PY
import json
from pathlib import Path
out = Path("$OUT")
print(f"{'run':6}  {'w47':>6}  {'w39':>6}")
w47s=[]; w39s=[]
for i in range(1,5):
    def score(name):
        p = out / f"{name}_r{i}.json"
        if not p.exists():
            return None
        d = json.loads(p.read_text())
        return sum((r.get("judgeScore") or 0) for r in d.get("results", []))
    a,b = score("w47"), score("w39")
    if a is not None: w47s.append(a)
    if b is not None: w39s.append(b)
    print(f"r{i:<5}  {a if a is not None else '-':>6}  {b if b is not None else '-':>6}")
if w47s:
    print(f"mean    {sum(w47s)/len(w47s):6.2f}  {sum(w39s)/len(w39s):6.2f}")
    print(f"min/max {min(w47s)}/{max(w47s)}      {min(w39s)}/{max(w39s)}")
PY
