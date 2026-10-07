#!/usr/bin/env bash
# Official tri-check eval (OpenClaw → Judge), 4 independent runs:
# w47 control + w51/w53/w54/w55 (best n=6 one-edits).
set -euo pipefail
ROOT="/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2"
OUT="$ROOT/local-work/p3-008/captures/tricheck_w47_top5_n4"
TPL_DIR="$ROOT/local-work/p3-008/templates_en"
NAMES=(w47 w51 w53 w54 w55)
declare -A TPL=(
  [w47]="$TPL_DIR/w47_shortprimer_filenote.json"
  [w51]="$TPL_DIR/w51_noblue.json"
  [w53]="$TPL_DIR/w53_nocoerce.json"
  [w54]="$TPL_DIR/w54_nostylehdr.json"
  [w55]="$TPL_DIR/w55_s1factsok.json"
)
mkdir -p "$OUT"
cd "$ROOT/tri-check"

for i in 1 2 3 4; do
  echo "===== ROUND $i/4 ====="
  pids=()
  for name in "${NAMES[@]}"; do
    pnpm eval --submission "${TPL[$name]}" --out "$OUT/${name}_r${i}.json" \
      > "$OUT/${name}_r${i}.log" 2>&1 &
    pids+=("$!")
  done
  exits=()
  for idx in "${!NAMES[@]}"; do
    wait "${pids[$idx]}"
    exits+=("$?")
  done
  echo -n "round $i exit:"
  for idx in "${!NAMES[@]}"; do
    echo -n " ${NAMES[$idx]}=${exits[$idx]}"
  done
  echo
  python3 - <<PY
import json
from pathlib import Path
out = Path("$OUT")
names = "w47 w51 w53 w54 w55".split()
i = $i
for name in names:
    p = out / f"{name}_r{i}.json"
    if not p.exists():
        print(f"  {name}: NO REPORT")
        continue
    d = json.loads(p.read_text())
    rows = {r["id"]: r for r in d.get("results", [])}
    bits = []
    tot = 0
    for q in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6"):
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
names = "w47 w51 w53 w54 w55".split()
print(f"{'run':6}" + "".join(f"  {n:>6}" for n in names))
scores = {n: [] for n in names}
for i in range(1, 5):
    row = [f"r{i:<5}"]
    for n in names:
        p = out / f"{n}_r{i}.json"
        if not p.exists():
            row.append(f"{'-':>6}")
            continue
        d = json.loads(p.read_text())
        s = sum((r.get("judgeScore") or 0) for r in d.get("results", []))
        scores[n].append(s)
        row.append(f"{s:>6}")
    print("  ".join(row))
print(f"{'mean':6}" + "".join(
    f"  {sum(scores[n])/len(scores[n]):6.2f}" if scores[n] else "       -"
    for n in names
))
print(f"{'min/mx':6}" + "".join(
    f"  {min(scores[n])}/{max(scores[n])}".rjust(6) if scores[n] else "       -"
    for n in names
))
PY
