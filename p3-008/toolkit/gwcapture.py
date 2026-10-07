"""gwcapture.py <template.json> [Qids|-] [n]

Run the REAL gateway (guard stays ON). When output-blocked, pick up the pre-block
assistant text dumped by the local guard-model patch into the mounted volume:

  tri-claw/docker/eval-fixtures/home/node/.openclaw/blocked-outputs/

Save each trial under local-work/p3-008/captures/<tplstem>/<qid>_n<k>.{json,txt}
and print tag + live output-guard fingerprint + judge of the captured text.
"""
import json, time, pathlib, sys
from _common import OBJS, QIDS, expand, gateway, judge, classify, blocked, load_tpl

ROOT = pathlib.Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2")
DUMP_DIR = ROOT / "tri-claw/docker/eval-fixtures/home/node/.openclaw/blocked-outputs"
CAP_ROOT = ROOT / "local-work/p3-008/captures"

def _list_dumps():
    if not DUMP_DIR.is_dir():
        return set()
    return {p.name for p in DUMP_DIR.glob("*.json")}

def _load_newest(before):
    after = _list_dumps()
    new = sorted(after - before)
    if not new:
        return None
    return json.loads((DUMP_DIR / new[-1]).read_text())

def _tag(resp):
    s = (resp or "").strip()
    if s.startswith("__ERROR__") or s == "":
        return "ERR"
    if s.startswith("Blocked by input guard"):
        return "IN-BLOCK"
    if s.startswith("Blocked by output guard"):
        return "OUT-BLOCK"
    if s.startswith("Blocked by"):
        return "BLOCK"
    return "PASS"

def trial(tpl, qid, outdir, k):
    prompt = expand(tpl, OBJS[qid])
    before = _list_dumps()
    resp = gateway(prompt)
    time.sleep(0.3)  # dump write is awaited before the throw, but be safe
    tag = _tag(resp)
    dumped = _load_newest(before) if tag == "OUT-BLOCK" else None
    text = (dumped or {}).get("text") if dumped else (resp if tag == "PASS" else "")
    og = classify(text, "output") if text else {}
    v, sc = (None, 0)
    if text:
        v, sc = judge(qid, prompt, text)
    rec = {
        "qid": qid,
        "n": k,
        "tag": tag,
        "gateway_head": (resp or "")[:120],
        "dump_ts": (dumped or {}).get("ts"),
        "dump_len": (dumped or {}).get("len") or len(text or ""),
        "outguard": {kk: og.get(kk) for kk in ("status", "score", "ffi", "latched", "pu", "cat")} if og else None,
        "judge": v,
        "score": sc or 0,
        "text": text,
    }
    stem = outdir / f"{qid}_n{k}"
    stem.with_suffix(".json").write_text(json.dumps({**rec, "text": text}, indent=2))
    if text:
        stem.with_suffix(".txt").write_text(text)
    og_s = rec["outguard"]
    og_part = ""
    if og_s:
        scv = og_s.get("score")
        scv = None if scv is None else round(float(scv), 3)
        og_part = f" og={og_s.get('status')} score={scv} ffi={og_s.get('ffi')}"
    print(f"{qid} n{k}: tag={tag} judge={sc}({v}) len={rec['dump_len']}{og_part}", flush=True)
    return rec

if __name__ == "__main__":
    tpl_path = sys.argv[1]
    tpl = load_tpl(tpl_path)
    qids = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "-" else QIDS
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    start = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    outdir = CAP_ROOT / pathlib.Path(tpl_path).stem
    outdir.mkdir(parents=True, exist_ok=True)
    DUMP_DIR.mkdir(parents=True, exist_ok=True)
    print(f"captures -> {outdir}  dumps <- {DUMP_DIR}  k={start}..{start+n-1}", flush=True)
    for qid in qids:
        for k in range(start, start + n):
            trial(tpl, qid, outdir, k)
