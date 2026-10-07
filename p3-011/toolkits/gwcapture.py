#!/usr/bin/env python3
"""p3-010 gateway capture. Writes local-work/p3-010/captures/<stem>/.

Uses the p3-009 _common helpers (same OpenClaw + judge + live output guard).
Input phase is whatever openclaw.json currently has. For a021 GCG acceptance
it must stay off until the input-guard pass.
"""
import json
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "p3-009" / "toolkit"))
from _common import OBJS, QIDS, expand, gateway, judge, classify, load_tpl  # noqa: E402

ROOT = HERE.parents[2]
DUMP_DIR = ROOT / "tri-claw/docker/eval-fixtures/home/node/.openclaw/blocked-outputs"
CAP_ROOT = HERE.parent / "captures"


def _list_dumps():
    if not DUMP_DIR.is_dir():
        return set()
    return {p.name for p in DUMP_DIR.glob("*.json")}


def _load_newest(before):
    new = sorted(_list_dumps() - before)
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
    time.sleep(0.3)
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
        "outguard": {kk: og.get(kk) for kk in ("status", "score", "ffi", "latched", "pu", "cat", "threshold")} if og else None,
        "judge": v,
        "score": sc or 0,
        "text": text,
    }
    stem = outdir / f"{qid}_n{k}"
    stem.with_suffix(".json").write_text(json.dumps(rec, indent=2))
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
