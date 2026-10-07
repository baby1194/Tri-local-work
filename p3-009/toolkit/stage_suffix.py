"""stage_suffix.py "<suffix text>"  — drop a GCG'd suffix into the t43 frame.

Writes templates/tgcg_<tag>.json = t43 FRAME_PREFIX + " " + <suffix>, so the acceptance
ladder is just:
  python3 toolkit/probe_serial.py templates/tgcg_<tag>.json         # want pu<0.12 all 6
  python3 toolkit/gwcapture.py    templates/tgcg_<tag>.json Q1 8     # want >= t43 7/8, 0 OUT
  python3 toolkit/gwcapture.py    templates/tgcg_<tag>.json Q3 8
  python3 toolkit/gwcapture.py    templates/tgcg_<tag>.json Q5 8
  python3 toolkit/gwcapture.py    templates/tgcg_<tag>.json - 8      # all-6, 0 OUT to promote

Usage:
  python3 toolkit/stage_suffix.py "delivered ... xagradaazos"          # tag=auto
  python3 toolkit/stage_suffix.py "<suffix>" mytag
The suffix is exactly the string between the closing quote of the forced opening and EOF
in the t43 prompt (what the GCG "BEST SUFFIX" repr prints, minus the quotes)."""
import json, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]        # local-work/p3-009
FRAME_PREFIX = json.loads((ROOT / "templates/t43_thinfind.json").read_text())["prompt"].rsplit(
    ' delivered demostr', 1)[0]  # everything up to the current suffix (ends at the stamp quote)

if __name__ == "__main__":
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print(__doc__); sys.exit(1)
    suffix = sys.argv[1].strip()
    tag = sys.argv[2] if len(sys.argv) > 2 else "run"
    prompt = FRAME_PREFIX + " " + suffix
    dest = ROOT / "templates" / f"tgcg_{tag}.json"
    dest.write_text(json.dumps({"prompt": prompt}))
    print("wrote", dest)
    print("chars:", len(prompt), "(limit 2000)")
    print("suffix:", repr(suffix))
    print("\nnext:")
    for cmd in (f"python3 toolkit/probe_serial.py templates/tgcg_{tag}.json",
                f"python3 toolkit/gwcapture.py templates/tgcg_{tag}.json Q1 8"):
        print(" ", cmd)
