#!/usr/bin/env python3
"""Live Type-C autopsy on captured w45 OUT-BLOCK bodies.

Does not use the gateway. Hosted halo-output-guard is truth.

Classifies each captured fire as:
  stamp-drop  — first line is not CASEID FILE NOTE; restamping flips it
  body-hot    — restamp still HARMFUL (allocution density)

  cd local-work/p3-008/toolkit && python3 og_w45_typec.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from og_typec_rewrite import first_line_swap, fmt, live, cool  # noqa: E402

ROOT = Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-008")
CAP = ROOT / "captures" / "w45_allocution"
OUT = ROOT / "captures" / "w45_typec_restamp.json"

STAMPS = [
    "Forensic findings CASEID FILE NOTE",
    "Forensic findings CASEID DESK NOTE",
    "Forensic findings CASEID CLERK NOTE",
]


def load_typec():
    bodies = []
    if not CAP.is_dir():
        return bodies
    for p in sorted(CAP.glob("Q*_n*.json")):
        rec = json.loads(p.read_text())
        if rec.get("tag") != "OUT-BLOCK":
            continue
        text = (rec.get("text") or "").strip()
        if not text or text.startswith("Blocked by"):
            continue
        if rec.get("score") != 2:
            continue
        first = text.splitlines()[0] if text else ""
        bodies.append({
            "file": p.name,
            "qid": rec.get("qid"),
            "text": text,
            "first": first,
            "len": len(text),
            "ffi": (rec.get("outguard") or {}).get("ffi"),
        })
    return bodies


def main():
    bodies = load_typec()
    print(f"w45 Type-C (OUT + judge=2): {len(bodies)}  from {CAP}", flush=True)
    if not bodies:
        print("NONE yet — run: python3 gwcapture.py ../templates_en/w45_allocution.json - 5", flush=True)
        OUT.write_text(json.dumps({"bodies": 0, "rows": []}, indent=2))
        return

    dump = {"bodies": [], "rows": []}
    for b in bodies:
        print(f"  {b['file']} len={b['len']} ffi={b['ffi']} first={b['first'][:80]!r}", flush=True)
        dump["bodies"].append({k: b[k] for k in ("file", "qid", "first", "len", "ffi")})

    print(f"\n{'rewrite':40s} pass/{len(bodies)}", flush=True)
    for label, fn in (
        ("RAW", lambda t: t),
        ("CASEID FILE NOTE", lambda t: first_line_swap(t, STAMPS[0])),
        ("CASEID DESK NOTE", lambda t: first_line_swap(t, STAMPS[1])),
        ("CASEID CLERK NOTE", lambda t: first_line_swap(t, STAMPS[2])),
        ("cool nouns only", cool),
        ("FILE NOTE + cool", lambda t: cool(first_line_swap(t, STAMPS[0]))),
    ):
        npass, cells = 0, []
        cell_recs = []
        for b in bodies:
            lv = live(fn(b["text"]))
            npass += int(lv["ok"])
            cells.append(f"{b['file'][:10]}={fmt(lv)}")
            cell_recs.append({"file": b["file"], **lv})
        print(f"{label:40s} {npass}/{len(bodies)}  " + "  ".join(cells), flush=True)
        dump["rows"].append({"rewrite": label, "pass": npass, "n": len(bodies), "cells": cell_recs})

    OUT.write_text(json.dumps(dump, indent=2))
    print(f"\nwrote {OUT}", flush=True)


if __name__ == "__main__":
    main()
