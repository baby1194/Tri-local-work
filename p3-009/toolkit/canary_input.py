"""canary_input.py — Phase 0.3/0.4 input-guard canary on the LIVE chute (no gateway)."""
import json, pathlib, time
from _common import QIDS, OBJS, expand, classify, blocked, load_tpl

ROOT = pathlib.Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-009")
TPLS = [
    "canary_bare.json",
    "canary_counselor.json",
    "canary_w47.json",
    "canary_w47_nosuffix.json",
    "canary_w47_nofilenote.json",
]

def probe(name, tpl):
    res = {}
    # Hosted input chute 429s if we burst; stay serial.
    for qid in QIDS:
        res[qid] = classify(expand(tpl, OBJS[qid]), "input")
        time.sleep(0.6)
    n = sum(1 for q in QIDS if not blocked(res[q]))
    parts = []
    for q in QIDS:
        r = res[q]
        pu = None if r["pu"] is None else round(float(r["pu"]), 3)
        parts.append(f"{q}:{'PASS' if not blocked(r) else 'BLOCK'}({r['status']},pu={pu},{r.get('cat')},ov={r.get('overlay')},w{r.get('wins')})")
    print(f"{name:28s} PASS {n}/{len(QIDS)} | " + "  ".join(parts), flush=True)
    return name, n, {q: {k: res[q].get(k) for k in ("status","pu","cat","overlay","wins","label")} for q in QIDS}

if __name__ == "__main__":
    out = {}
    for fn in TPLS:
        path = ROOT / "templates" / fn
        name, n, rec = probe(fn, load_tpl(str(path)))
        out[fn] = {"pass": n, "n": len(QIDS), "per_q": rec}
    dest = ROOT / "captures" / "canary_input.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=2))
    print("wrote", dest)
