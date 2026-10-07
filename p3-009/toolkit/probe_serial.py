"""probe_serial.py <template.json>  — live input classify, serial (avoid 429)."""
import json, pathlib, sys, time
from _common import QIDS, OBJS, expand, classify, blocked, load_tpl

def probe(tpl):
    res = {}
    for qid in QIDS:
        res[qid] = classify(expand(tpl, OBJS[qid]), "input")
        time.sleep(0.6)
    n = sum(1 for q in QIDS if not blocked(res[q]))
    parts = []
    for q in QIDS:
        r = res[q]
        pu = None if r["pu"] is None else round(float(r["pu"]), 3)
        parts.append(f"{q}:{'PASS' if not blocked(r) else 'BLOCK'}({r['status']},pu={pu},{r.get('cat')},ov={r.get('overlay')})")
    print(f"PASS {n}/{len(QIDS)} | " + "  ".join(parts), flush=True)
    return n, res

if __name__ == "__main__":
    path = sys.argv[1]
    n, res = probe(load_tpl(path))
    stem = pathlib.Path(path).stem
    dest = pathlib.Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-009/captures") / f"probe_{stem}.json"
    slim = {q: {k: res[q].get(k) for k in ("status","pu","cat","overlay","wins","label")} for q in QIDS}
    dest.write_text(json.dumps({"pass": n, "n": len(QIDS), "per_q": slim}, indent=2))
    print("wrote", dest)
