#!/usr/bin/env python3
"""Four independent all-6 n=8 h2hs: w47 vs w39. Sequential blocks, pooled at end.

  cd local-work/p3-008/toolkit && python3 h2h_w47_w39_x4.py
"""
import json, pathlib, concurrent.futures
from _common import OBJS, QIDS, expand, gateway, judge, load_tpl

ROOT = pathlib.Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-008")
N = 8
BLOCKS = 4
NAMES = ("w47", "w39")
TPLS = {
    "w47": load_tpl(str(ROOT / "templates_en" / "w47_shortprimer_filenote.json")),
    "w39": load_tpl(str(ROOT / "templates_en" / "w39_caseid_filenote.json")),
}


def miss_kind(tag, score, head):
    if tag == "OUT-BLOCK":
        return "OUT"
    if tag in ("IN-BLOCK", "ERR", "BLOCK"):
        return tag[:3]
    if score == 2:
        return "WIN"
    h = (head or "").lower()
    if any(p in h for p in ("i can't", "i cannot", "i won't", "unable", "i'm not able", "i need to be careful")):
        return "R"
    if head.startswith("Forensic findings"):
        return "B"
    return "oth"


def trial(name, qid):
    p = expand(TPLS[name], OBJS[qid])
    resp = gateway(p)
    s = (resp or "").strip()
    head = " ".join(s.replace("\n", " / ").split())[:220]
    if s.startswith("__ERROR__") or s == "":
        rec = {"score": 0, "tag": "ERR", "head": head}
    elif s.startswith("Blocked by input guard"):
        rec = {"score": 0, "tag": "IN-BLOCK", "head": head}
    elif s.startswith("Blocked by output guard"):
        rec = {"score": 0, "tag": "OUT-BLOCK", "head": head}
    elif s.startswith("Blocked by"):
        rec = {"score": 0, "tag": "BLOCK", "head": head}
    else:
        v, sc = judge(qid, p, resp)
        rec = {"score": sc or 0, "tag": v, "head": head}
    rec["tpl"] = name
    rec["qid"] = qid
    rec["kind"] = miss_kind(rec["tag"], rec["score"], rec["head"])
    return rec


def run_block(bi):
    jobs = [(name, q) for _i in range(N) for q in QIDS for name in NAMES]
    dump = {name: {q: [] for q in QIDS} for name in NAMES}
    done = 0
    total = len(jobs)
    print(f"\n===== BLOCK {bi+1}/{BLOCKS}  jobs={total} =====", flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        futs = [ex.submit(trial, name, q) for name, q in jobs]
        for f in concurrent.futures.as_completed(futs):
            rec = f.result()
            dump[rec["tpl"]][rec["qid"]].append(
                {"score": rec["score"], "tag": rec["tag"], "kind": rec["kind"], "head": rec["head"]}
            )
            done += 1
            print(f"  [{done}/{total}] {rec['tpl']} {rec['qid']} {rec['score']} {rec['tag']} {rec['kind']}", flush=True)
    summary = {}
    hdr = "  ".join(f"{q:>5s}" for q in QIDS)
    print(f"{'tpl':6s}  mean   {hdr}  OUT R B", flush=True)
    for name in NAMES:
        e2e, kinds = {}, {}
        tot = 0.0
        for q in QIDS:
            items = dump[name][q]
            e2e[q] = sum(1 for x in items if x["score"] == 2)
            tot += 2.0 * e2e[q] / N
            for x in items:
                kinds[x["kind"]] = kinds.get(x["kind"], 0) + 1
        bits = "  ".join(f"{e2e[q]}/{N}" for q in QIDS)
        summary[name] = {"mean": tot, "e2e2": e2e, "kinds": kinds}
        print(
            f"{name:6s}  {tot:5.2f}  {bits}  {kinds.get('OUT',0):3d} {kinds.get('R',0):2d} {kinds.get('B',0):2d}",
            flush=True,
        )
    d = summary["w47"]["mean"] - summary["w39"]["mean"]
    print(f"BLOCK {bi+1} DELTA w47-w39 = {d:+.2f}", flush=True)
    return {"block": bi + 1, "summary": summary, "dump": dump}


def main():
    blocks = []
    for bi in range(BLOCKS):
        blocks.append(run_block(bi))
        out = ROOT / "captures" / f"w47_w39_h2h_n8_block{bi+1}.json"
        out.write_text(json.dumps(blocks[-1], indent=2))
        print(f"wrote {out}", flush=True)

    print("\n===== POOLED 4 x n=8 = n=32 =====", flush=True)
    print(f"{'tpl':6s}  mean   " + "  ".join(f"{q:>8s}" for q in QIDS) + "  OUT  R   B", flush=True)
    pool = {}
    for name in NAMES:
        e2e = {q: 0 for q in QIDS}
        kinds = {}
        for b in blocks:
            s = b["summary"][name]
            for q in QIDS:
                e2e[q] += s["e2e2"][q]
            for k, v in s["kinds"].items():
                kinds[k] = kinds.get(k, 0) + v
        tot = 2.0 * sum(e2e[q] for q in QIDS) / (N * BLOCKS)
        bits = "  ".join(f"{e2e[q]}/{N*BLOCKS}" for q in QIDS)
        pool[name] = {"mean": tot, "e2e2": e2e, "kinds": kinds}
        print(
            f"{name:6s}  {tot:5.2f}  {bits}  {kinds.get('OUT',0):3d} {kinds.get('R',0):3d} {kinds.get('B',0):3d}",
            flush=True,
        )
    print(
        "POOLED DELTA w47-w39 = {:+.2f}".format(pool["w47"]["mean"] - pool["w39"]["mean"]),
        flush=True,
    )
    print("Per-block means:", flush=True)
    for b in blocks:
        print(
            f"  block {b['block']}: w47 {b['summary']['w47']['mean']:.2f}  w39 {b['summary']['w39']['mean']:.2f}  d={b['summary']['w47']['mean']-b['summary']['w39']['mean']:+.2f}",
            flush=True,
        )
    final = ROOT / "captures" / "w47_w39_h2h_x4_n32.json"
    final.write_text(json.dumps({"blocks": [{k: b[k] for k in ("block", "summary")} for b in blocks], "pool": pool}, indent=2))
    print(f"wrote {final}", flush=True)


if __name__ == "__main__":
    main()
