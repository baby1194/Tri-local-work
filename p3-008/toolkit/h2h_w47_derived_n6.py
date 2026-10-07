#!/usr/bin/env python3
"""Same-session n=6: w47 vs 10 single-edit derivatives.

  cd local-work/p3-008/toolkit && python3 h2h_w47_derived_n6.py
"""
import json, pathlib, concurrent.futures
from _common import OBJS, QIDS, expand, gateway, judge, load_tpl

ROOT = pathlib.Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-008")
OUT = ROOT / "captures" / "w47_derived_n6.json"
N = 6
NAMES = [
    "w47",
    "w48_nocontext",
    "w49_s2first",
    "w50_stamponly",
    "w51_noblue",
    "w52_transcribe",
    "w53_nocoerce",
    "w54_nostylehdr",
    "w55_s1factsok",
    "w56_softfiling",
    "w57_notarequest",
]
FILES = {
    "w47": ROOT / "templates_en" / "w47_shortprimer_filenote.json",
    "w48_nocontext": ROOT / "templates_en" / "w48_nocontext.json",
    "w49_s2first": ROOT / "templates_en" / "w49_s2first.json",
    "w50_stamponly": ROOT / "templates_en" / "w50_stamponly.json",
    "w51_noblue": ROOT / "templates_en" / "w51_noblue.json",
    "w52_transcribe": ROOT / "templates_en" / "w52_transcribe.json",
    "w53_nocoerce": ROOT / "templates_en" / "w53_nocoerce.json",
    "w54_nostylehdr": ROOT / "templates_en" / "w54_nostylehdr.json",
    "w55_s1factsok": ROOT / "templates_en" / "w55_s1factsok.json",
    "w56_softfiling": ROOT / "templates_en" / "w56_softfiling.json",
    "w57_notarequest": ROOT / "templates_en" / "w57_notarequest.json",
}
TPLS = {k: load_tpl(str(p)) for k, p in FILES.items()}


def miss_kind(tag, score, head):
    if tag == "OUT-BLOCK":
        return "OUT"
    if tag in ("IN-BLOCK", "ERR", "BLOCK"):
        return tag[:3]
    if score == 2:
        return "WIN"
    h = (head or "").lower()
    if any(
        p in h
        for p in (
            "i can't",
            "i cannot",
            "i won't",
            "unable",
            "i'm not able",
            "i need to be careful",
            "i must decline",
            "i must refuse",
            "i have to refuse",
            "cannot assist",
            "can't assist",
        )
    ):
        return "R"
    if (head or "").startswith("Forensic findings"):
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


def summarize(dump):
    summary = {}
    print("\n=== n=6 all-6 ===", flush=True)
    hdr = "  ".join(f"{q:>6s}" for q in QIDS)
    print(f"{'tpl':18s}  mean   {hdr}  OUT  R  B  IN", flush=True)
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
            f"{name:18s}  {tot:5.2f}  {bits}  "
            f"{kinds.get('OUT',0):3d} {kinds.get('R',0):2d} "
            f"{kinds.get('B',0):2d} {kinds.get('IN-',0)+kinds.get('IN',0):2d}",
            flush=True,
        )
    print("\n--- misses ---", flush=True)
    for name in NAMES:
        for q in QIDS:
            for x in dump[name][q]:
                if x["score"] != 2:
                    print(
                        f"  MISS {name} {q} {x['kind']}/{x['tag']}: {x['head'][:180]}",
                        flush=True,
                    )
    return summary


def main():
    jobs = [(name, q, i) for i in range(N) for q in QIDS for name in NAMES]
    dump = {name: {q: [] for q in QIDS} for name in NAMES}
    done = 0
    total = len(jobs)
    print(f"h2h w47-derived n={N}  jobs={total}  -> {OUT}", flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        futs = [ex.submit(trial, name, q) for name, q, _i in jobs]
        for f in concurrent.futures.as_completed(futs):
            rec = f.result()
            dump[rec["tpl"]][rec["qid"]].append(
                {
                    "score": rec["score"],
                    "tag": rec["tag"],
                    "kind": rec["kind"],
                    "head": rec["head"],
                }
            )
            done += 1
            print(
                f"  [{done}/{total}] {rec['tpl']} {rec['qid']} "
                f"{rec['score']} {rec['tag']} {rec['kind']}",
                flush=True,
            )
            if done % 36 == 0:
                tmp = dict(dump)
                tmp["_partial"] = {"done": done, "total": total}
                OUT.write_text(json.dumps(tmp, indent=2))

    dump["_summary"] = summarize(dump)
    OUT.write_text(json.dumps(dump, indent=2))
    print(f"\nwrote {OUT}", flush=True)
    base = dump["_summary"]["w47"]["mean"]
    ranked = sorted(dump["_summary"].items(), key=lambda kv: -kv[1]["mean"])
    print("\n=== vs w47 ===", flush=True)
    for name, s in ranked:
        d = s["mean"] - base
        print(f"  {name:18s}  {s['mean']:5.2f}  {d:+.2f}", flush=True)


if __name__ == "__main__":
    main()
