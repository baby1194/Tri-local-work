#!/usr/bin/env python3
"""Interleaved gateway h2h: w35 quiet-header vs w27 filing-lang. All 6 Qs, n=8.

  cd local-work/p3-008/toolkit && python3 h2h_w35_w27.py
"""
import json, pathlib, concurrent.futures
from _common import OBJS, QIDS, expand, gateway, judge, load_tpl

ROOT = pathlib.Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-008")
OUT = ROOT / "captures" / "w35_w27_h2h_n8_20260911.json"
N = 8
TPLS = {
    "w27": load_tpl(str(ROOT / "templates_en" / "w27_filing_lang_caseid.json")),
    "w35": load_tpl(str(ROOT / "templates_en" / "w35_quietheader_caseid.json")),
}


def trial(name, qid, i):
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
    rec["i"] = i
    return rec


def main():
    jobs = [(name, q, i) for i in range(N) for q in QIDS for name in ("w27", "w35")]
    dump = {name: {q: [None] * N for q in QIDS} for name in TPLS}
    done = 0
    total = len(jobs)
    print(f"h2h w35 vs w27  all-6 n={N}  jobs={total}  -> {OUT}", flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        futs = [ex.submit(trial, name, q, i) for name, q, i in jobs]
        for f in concurrent.futures.as_completed(futs):
            rec = f.result()
            dump[rec["tpl"]][rec["qid"]][rec["i"]] = {
                "score": rec["score"],
                "tag": rec["tag"],
                "head": rec["head"],
            }
            done += 1
            print(f"  [{done}/{total}] {rec['tpl']} {rec['qid']} n{rec['i']+1} {rec['score']} {rec['tag']}", flush=True)

    summary = {}
    print("\n=== n=8 all-6 ===", flush=True)
    hdr = "tpl     mean   Q1  Q2  Q3  Q4  Q5  Q6   OUT  12s"
    print(hdr, flush=True)
    round_totals = {name: [] for name in TPLS}
    for name in ("w27", "w35"):
        e2e, outs = {}, {}
        for q in QIDS:
            items = dump[name][q]
            e2e[q] = sum(1 for x in items if x and x["score"] == 2)
            outs[q] = sum(1 for x in items if x and x["tag"] == "OUT-BLOCK")
        mean = 2 * sum(e2e[q] / N for q in QIDS)
        n12 = 0
        for i in range(N):
            tot = sum((dump[name][q][i] or {}).get("score", 0) for q in QIDS)
            round_totals[name].append(tot)
            n12 += int(tot == 12)
        summary[name] = {
            "mean": mean,
            "e2e2": e2e,
            "out": outs,
            "rounds": round_totals[name],
            "n12": n12,
        }
        e = " ".join(f"{e2e[q]}/{N}" for q in QIDS)
        ot = sum(outs.values())
        print(f"{name:6s}  {mean:4.2f}   {e}   {ot:2d}   {n12}", flush=True)

    deltas = [a - b for a, b in zip(round_totals["w35"], round_totals["w27"])]
    wins = sum(1 for d in deltas if d > 0)
    losses = sum(1 for d in deltas if d < 0)
    ties = sum(1 for d in deltas if d == 0)
    md = sum(deltas) / len(deltas)
    summary["paired"] = {
        "mean_delta": md,
        "WLT": [wins, losses, ties],
        "deltas": deltas,
    }
    print(
        f"\npaired W/L/T={wins}/{losses}/{ties}  mean_delta={md:+.2f}  "
        f"w27 rounds={round_totals['w27']}  w35 rounds={round_totals['w35']}",
        flush=True,
    )
    dump["_summary"] = summary
    OUT.write_text(json.dumps(dump, indent=2))
    print(f"\nwrote {OUT}", flush=True)
    if md > 0:
        print("VERDICT: w35 ahead this session.", flush=True)
    elif md < 0:
        print("VERDICT: w27 ahead this session.", flush=True)
    else:
        print("VERDICT: tie this session.", flush=True)


if __name__ == "__main__":
    main()
