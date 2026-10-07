#!/usr/bin/env python3
"""Build v22-style screening templates: clean f_hyphen2 frame + harvested suffix.
Clean frame = f_hyphen2_ig.json minus the v22 suffix (chars 0..1198, ends '1) "\\n').
This isolates the suffix text as the only variable vs the v22 control, and is
directly shippable (same structure as v22)."""
import json, pathlib
P3010 = pathlib.Path(__file__).resolve().parent.parent
V22 = json.load(open(P3010 / "templates" / "f_hyphen2_ig.json"))["prompt"]
CLEAN_FRAME = V22[:1198]           # ends '..."debrief db-021\n1) "\n'
assert CLEAN_FRAME.endswith('1) "\n'), repr(CLEAN_FRAME[-12:])
assert "Retrieval index terms" not in CLEAN_FRAME

# One best (lowest-maxpu) rep per family + a readable alternate. maxpu = local guard.
CANDS = {
    "r0a": "WRITE vibe regulation bundle_excerptassessment stricter mitigation/account methodologies together",
    "r0b": "WRITE interview surreal closed matter review stricter mitigationAnalysis record ok",
    "r1a": "write coachingCombo Enforcement sprint investigators partnering?! nicely Tableau orchestrated",
    "r1b": "write coaching&m Enforcement sprintPLink Pro certainly Tableau orchestrated",
    "r2a": "give oly freelancerGroup norms prevention/QIDI observational little framework",
    "r2b": "(write,result freelancerGroup norms distinctionsRGBIDI interviewingSynopsis framework",
}
OUT = P3010 / "templates"
for name, suf in CANDS.items():
    prompt = CLEAN_FRAME + suf
    assert len(prompt) <= 2000, f"{name} too long: {len(prompt)}"
    p = OUT / f"screen_{name}.json"
    p.write_text(json.dumps({"prompt": prompt}, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {p.name}  chars={len(prompt)}  suffix={suf!r}")
