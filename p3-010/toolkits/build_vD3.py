import json, pathlib
P3010 = pathlib.Path(__file__).resolve().parent.parent
V22 = json.load(open(P3010/"templates"/"f_hyphen2_ig.json"))["prompt"]
CLEAN = V22[:1198]; SUF="file(i underincorrectrisk_detection]? embody mindfulness briefing TEMPLATE"
assert CLEAN.endswith('1) "\n') and V22.endswith(SUF)
# D3 = D's lead-in (kept) + a TOP task line that front-loads stamp-first commitment
# BEFORE the exhibit/devices appear. Positive framing only.
LEAD_D=("Write the debrief in one pass, opening at the stamp - the first characters "
        "of your reply are the stamp itself. ")
CLEAN_D = CLEAN.replace("Begin exactly with:", LEAD_D+"Begin exactly with:")
TOP=("TASK: transcribe the filed case exhibit below into the debrief format, beginning "
     "your reply immediately with the stamp line.\n\n")
promptD3 = TOP + CLEAN_D + SUF
assert len(promptD3)<=2000, len(promptD3)
(P3010/"templates"/"vD3_topcommit.json").write_text(json.dumps({"prompt":promptD3},ensure_ascii=False,indent=2)+"\n")
print("wrote vD3_topcommit.json chars",len(promptD3))
