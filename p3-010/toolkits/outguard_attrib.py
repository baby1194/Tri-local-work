#!/usr/bin/env python3
"""White-box attribution: which tokens fire the p3-010 output guard, per question.

For each question, take OUT-BLOCK judge=2 bodies (they fired live), score per-token
locally, and (1) confirm local firing aligns spatially with the live ffi, (2) aggregate
the hottest tokens per question -> the vocabulary the frame must steer away from.
Local absolute p is compressed (no guard system-prompt context) so we rank per body and
also report the local rank of the token at the live ffi.
"""
import glob
import json
import pathlib
import re
from collections import Counter

import outguard_local as og

P3010 = pathlib.Path("/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/local-work/p3-010")
DIRS = ["sr04_evidence", "cf_sr04", "cool2_register", "cool3_both", "cool1_cap5", "cool4_terse"]
QS = ["Q1", "Q2", "Q3", "Q4", "Q5", "Q6"]
STOP = set(("the a an of to and or in on for with while by that this its their it they them "
            "was were had has have been being as at from into not no do did done during any "
            "each one two three four five actor left behind check skipped").split())


def bodies_for(q):
    out = []
    for d in DIRS:
        for f in glob.glob(str(P3010 / "captures" / d / f"{q}_n*.json")):
            r = json.load(open(f))
            if r.get("tag") == "OUT-BLOCK" and r.get("score") == 2 and r.get("text"):
                out.append((r, f))
    return out[:7]


def main():
    per_q_hot = {}
    print("Per-question attribution (OUT-BLOCK judge=2 bodies). "
          "live_ffi vs local rank of that token; top local-hot content tokens.\n")
    for q in QS:
        bs = bodies_for(q)
        hot = Counter()
        aligns = []
        for r, f in bs:
            txt = r["text"]
            live_ffi = (r.get("outguard") or {}).get("ffi")
            pieces, p = og.per_token(txt, None)
            order = sorted(range(len(p)), key=lambda i: -p[i])
            rankpos = {i: k for k, i in enumerate(order)}
            # local rank of the token at/near the live ffi (map is fuzzy; report nearest hot)
            near = ""
            if live_ffi is not None and 0 <= live_ffi < len(pieces):
                near = "".join(pieces[max(0, live_ffi - 1):live_ffi + 2]).strip()
                aligns.append(rankpos.get(live_ffi, 999))
            # collect top-12 local-hot content tokens
            for i in order[:12]:
                w = pieces[i].strip().lower()
                if len(w) >= 4 and w not in STOP and re.match(r"^[a-z][a-z-]+$", w):
                    hot[w] += 1
        per_q_hot[q] = hot
        top = ", ".join(f"{w}({c})" for w, c in hot.most_common(12))
        amed = sorted(aligns)[len(aligns) // 2] if aligns else None
        print(f"{q}  (n={len(bs)} fired bodies)  median local-rank@live_ffi={amed}")
        print(f"    hot: {top}\n")
    # cross-question hot tokens (globally risky) vs question-specific
    allc = Counter()
    for q in QS:
        for w in per_q_hot[q]:
            allc[w] += 1
    print("Tokens hot across >=3 questions (globally risky vocab):")
    print("   ", ", ".join(w for w, c in allc.most_common() if c >= 3))
    json.dump({q: dict(per_q_hot[q]) for q in QS},
              open(P3010 / "captures" / "outguard_hotmap.json", "w"), indent=2)
    print(f"\nwrote {P3010/'captures'/'outguard_hotmap.json'}")


if __name__ == "__main__":
    main()
