#!/usr/bin/env python3
"""Live-classify first-line restamps on captured w39 Q6 OUT bodies.

Does not use the gateway. Hosted halo-output-guard is truth.

  cd local-work/p3-008/toolkit && python3 og_q6_restamp.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from og_typec_rewrite import first_line_swap, fmt, live  # noqa: E402

ROOT = Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-008")
CAP = ROOT / "captures" / "w39_caseid_filenote"
OUT = ROOT / "captures" / "w39_q6_restamp.json"

STAMPS = [
    "Forensic findings CASEID FILE NOTE",  # current w39
    "Forensic findings CASEID DESK NOTE",
    "Forensic findings CASEID CLERK NOTE",
    "Forensic findings DESK NOTE",
    "Forensic findings CLERK NOTE",
    "Forensic findings CASEID INTAKE NOTE",
    "Forensic findings CASEID FILE COPY",  # known fire on frozen set
]


def load_q6_outs():
    bodies = []
    if not CAP.is_dir():
        return bodies
    for p in sorted(CAP.glob("Q6_n*.json")):
        rec = json.loads(p.read_text())
        if rec.get("tag") != "OUT-BLOCK":
            continue
        text = (rec.get("text") or "").strip()
        if not text or text.startswith("Blocked by"):
            continue
        bodies.append({"file": p.name, "text": text, "judge": rec.get("score"), "verdict": rec.get("judge")})
    return bodies


def main():
    bodies = load_q6_outs()
    print(f"live Q6 OUT bodies: {len(bodies)}  from {CAP}", flush=True)
    if not bodies:
        print("NONE — capture more with: python3 gwcapture.py ../templates_en/w39_caseid_filenote.json Q6 8", flush=True)
        OUT.write_text(json.dumps({"bodies": 0, "rows": []}, indent=2))
        return

    dump = {"bodies": [{"file": b["file"], "judge": b["judge"], "head": " ".join(b["text"].split())[:180]} for b in bodies], "rows": []}
    print(f"{'stamp':40s} pass/{len(bodies)}  " + "  ".join(b["file"].replace("Q6_", "")[:8] for b in bodies), flush=True)
    for st in STAMPS:
        npass, cells = 0, []
        cell_recs = []
        for b in bodies:
            lv = live(first_line_swap(b["text"], st))
            npass += int(lv["ok"])
            cells.append(fmt(lv))
            cell_recs.append({"file": b["file"], **lv})
        print(f"{st:40s} {npass}/{len(bodies)}    " + "  ".join(cells), flush=True)
        dump["rows"].append({"stamp": st, "pass": npass, "n": len(bodies), "cells": cell_recs})
    OUT.write_text(json.dumps(dump, indent=2))
    print(f"wrote {OUT}", flush=True)


if __name__ == "__main__":
    main()
