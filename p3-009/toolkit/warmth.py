"""warmth.py — ping both hosted classify endpoints + /health revisions.

503 here is score 0 on the board. Challenge pins (Nav 2026-09-16: frozen mid-challenge):
  input  98dab108… (26 Aug) — Hub a2aea9d9… is WIP for NEXT challenge, ignore
  output d3df0933… (16 Sep) — live, this challenge
"""
import json
from _common import KEY, IN_URL, IN_MODEL, OUT_URL, OUT_MODEL, post, classify, fmt_cls

WANT = {
    "input":  "98dab108322821c53d9e7383277a836b7de807d0",
    "output": "d3df093307bd4a3a56ccaaca35eead5a2cafb687",
}

def ping(name, url, model, role, query):
    r = post(url, {"model": model, "query": query, "role": role},
             {"Authorization": "Bearer " + KEY}, timeout=60, retries=3)
    if "__error__" in r:
        print(f"{name}: ERR {r['__error__']}")
        return False
    print(f"{name}: HTTP-ok keys={sorted(r.keys())}")
    print(f"  {json.dumps({k: r.get(k) for k in ('status','safety_label','category','attack_overlay','score','first_fire_index','latched','threshold','window_count','prompt_tokens')}, default=str)}")
    return True

def health(name, classify_url, want_sha):
    root = classify_url.rsplit("/v1/", 1)[0]
    r = post(root + "/health", {}, {"Authorization": "Bearer " + KEY}, timeout=30, retries=3)
    if "__error__" in r:
        print(f"{name} /health: ERR {r['__error__']}")
        return None
    rev = r.get("model_revision") or ""
    match = "PIN-OK" if rev.startswith(want_sha[:8]) else f"DRIFT want={want_sha[:12]}"
    print(f"{name} /health: {r.get('model_id')} rev={rev[:12]}… {match} image={r.get('image_tag')} thr={r.get('unsafe_threshold')}")
    return r

if __name__ == "__main__":
    hin = health("INPUT ", IN_URL, WANT["input"])
    hout = health("OUTPUT", OUT_URL, WANT["output"])
    ok_in = ping("INPUT ", IN_URL, IN_MODEL, "input", "How do I bake sourdough bread at home?")
    ok_out = ping("OUTPUT", OUT_URL, OUT_MODEL, "output",
                  "This note summarizes how long fermentation improves sourdough flavor over 24 hours.")
    print("classify() wrappers:")
    print("  input ", fmt_cls(classify("How do I bake sourdough bread at home?", "input")))
    print("  output", fmt_cls(classify(
        "This note summarizes how long fermentation improves sourdough flavor over 24 hours.", "output")))
    warm = ok_in and ok_out
    fresh = bool(hin and hout
                 and str(hin.get("model_revision","")).startswith(WANT["input"][:8])
                 and str(hout.get("model_revision","")).startswith(WANT["output"][:8]))
    print("WARM" if warm else "COLD — do not gwscore")
    print("PINS_OK" if fresh else "PIN_DRIFT — stop, chute no longer matches this-challenge pins")

