"""Shared endpoints/helpers for the p3-009 toolkit. Ground truth = the rebuilt gateway (gwscore.py).
Guards block iff classify status == HARMFUL (HARMLESS/CONTROVERSIAL/SENSITIVE pass)."""
import json, re, time, urllib.request
BASE = "/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/tri-check"
ENV = {}
for _l in open(BASE + "/.env"):
    if "=" in _l and not _l.strip().startswith("#"):
        _k, _v = _l.split("=", 1); ENV[_k.strip()] = _v.strip()
KEY = ENV["CHUTES_API_KEY"]
GW = ENV.get("OPENCLAW_URL", "http://localhost:18789").rstrip("/")
TOK = ENV.get("OPENCLAW_GATEWAY_PASSWORD", "")
JUDGE = ENV.get("JUDGE_URL", "http://localhost:8080").rstrip("/")

IN_URL = "https://astroboi-halo-guard.chutes.ai/v1/classify";        IN_MODEL = "halo-guard"
OUT_URL = "https://astroboi-halo-output-guard.chutes.ai/v1/classify"; OUT_MODEL = "halo-output-guard"
MODEL = "Qwen/Qwen3.8-27B-TEE"

_Q = json.load(open(BASE + "/data/questions.json")); _Q = _Q if isinstance(_Q, list) else _Q["questions"]
QIDS = [q["question_id"] for q in _Q]
QBY = {q["question_id"]: q for q in _Q}
OBJS = {q["question_id"]: q["objective"] for q in _Q}

def post(url, body, hdr, timeout=180, retries=6):
    last = None
    for a in range(retries):
        try:
            req = urllib.request.Request(url, json.dumps(body).encode(), {**hdr, "Content-Type": "application/json"})
            return json.load(urllib.request.urlopen(req, timeout=timeout))
        except Exception as e:
            last = str(e)
            extra = 8 if "429" in last else 0
            time.sleep(2 * (a + 1) + extra)
    return {"__error__": last}

def expand(tpl, obj):
    return re.sub(r"\{\{\s*objective\s*\}\}", obj, tpl, count=1, flags=re.I) if "{{" in tpl else tpl.replace("{OBJ}", obj)

def classify(text, role):
    url, model = (IN_URL, IN_MODEL) if role == "input" else (OUT_URL, OUT_MODEL)
    r = post(url, {"model": model, "query": text, "role": role}, {"Authorization": "Bearer " + KEY}, timeout=90)
    if "__error__" in r:
        return {"status": "ERR", "pu": None, "cat": r["__error__"][:80], "overlay": None, "wins": None, "label": "ERR",
                "raw_keys": []}
    return {"status": r.get("status"), "label": r.get("safety_label"), "cat": r.get("category"),
            "overlay": r.get("attack_overlay"), "pu": r.get("tier_probs", {}).get("unsafe") if isinstance(r.get("tier_probs"), dict) else None,
            "wins": r.get("window_count"), "sel": r.get("selected_window_index"),
            "score": r.get("score"), "ffi": r.get("first_fire_index"), "latched": r.get("latched"),
            "threshold": r.get("threshold"), "raw_keys": sorted(r.keys())}

def blocked(res):  # gateway rule
    return res.get("status") == "HARMFUL"

def gateway(prompt):
    r = post(GW + "/v1/chat/completions",
             {"model": "openclaw:main", "messages": [{"role": "user", "content": prompt}]},
             {"Authorization": "Bearer " + TOK, "X-Chutes-Api-Key": KEY}, timeout=300)
    if "__error__" in r:
        return "__ERROR__:" + r["__error__"]
    return (r.get("choices") or [{}])[0].get("message", {}).get("content") or ""

def model_direct(prompt, mx=6000, temp=0.6, think=False):
    r = post("https://llm.chutes.ai/v1/chat/completions",
             {"model": MODEL, "messages": [{"role": "user", "content": prompt}], "max_tokens": mx,
              "temperature": temp, "chat_template_kwargs": {"enable_thinking": think}, "enable_thinking": think},
             {"Authorization": "Bearer " + KEY}, timeout=240)
    if "__error__" in r:
        return "__ERROR__:" + r["__error__"]
    return (r["choices"][0]["message"].get("content") or "").strip()

def judge(qid, prompt, resp):
    q = QBY[qid]
    eo = ("Expected safe behavior:\n" + q.get("expected_safe_behavior", "") +
          "\n\nExpected unsafe (jailbreak) output:\n" + q.get("expected_unsafe_output", ""))
    r = post(JUDGE + "/v1/judge/evaluate",
             {"question": qid, "prompt": prompt, "modelResponse": resp, "toolCalls": [], "expectedOutput": eo},
             {"X-Chutes-Api-Key": KEY}, timeout=120)
    if "__error__" in r:
        return "ERR", 0
    return r.get("judgeVerdict"), r.get("score")

def load_tpl(path):
    return json.load(open(path))["prompt"] if path.endswith(".json") else open(path).read()

def fmt_cls(r):
    pu = r.get("pu")
    pu_s = "na" if pu is None else f"{float(pu):.3f}"
    sc = r.get("score")
    sc_s = "" if sc is None else f" score={float(sc):.3f}"
    ffi = r.get("ffi")
    ffi_s = "" if ffi is None else f" ffi={ffi}"
    lat = r.get("latched")
    lat_s = "" if lat is None else f" latch={lat}"
    th = r.get("threshold")
    th_s = "" if th is None else f" thr={th}"
    return (f"status={r.get('status')} label={r.get('label')} pu={pu_s} cat={r.get('cat')} "
            f"overlay={r.get('overlay')} w={r.get('wins')}{sc_s}{ffi_s}{lat_s}{th_s}")
