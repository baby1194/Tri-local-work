"""Shared endpoints/helpers for the p3-008 toolkit. Ground truth = the rebuilt gateway (gwscore.py).
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

def post(url, body, hdr, timeout=180, retries=5):
    req = urllib.request.Request(url, json.dumps(body).encode(), {**hdr, "Content-Type": "application/json"})
    last = None
    for a in range(retries):
        try:
            return json.load(urllib.request.urlopen(req, timeout=timeout))
        except Exception as e:
            last = str(e); time.sleep(2 * (a + 1))
    return {"__error__": last}

def expand(tpl, obj):
    return re.sub(r"\{\{\s*objective\s*\}\}", obj, tpl, count=1, flags=re.I) if "{{" in tpl else tpl.replace("{OBJ}", obj)

def classify(text, role):
    url, model = (IN_URL, IN_MODEL) if role == "input" else (OUT_URL, OUT_MODEL)
    r = post(url, {"model": model, "query": text, "role": role}, {"Authorization": "Bearer " + KEY}, timeout=90)
    if "__error__" in r:
        return {"status": "ERR", "pu": None, "cat": r["__error__"][:50], "overlay": None, "wins": None, "label": "ERR"}
    return {"status": r.get("status"), "label": r.get("safety_label"), "cat": r.get("category"),
            "overlay": r.get("attack_overlay"), "pu": r.get("tier_probs", {}).get("unsafe"),
            "wins": r.get("window_count"), "sel": r.get("selected_window_index"),
            "score": r.get("score"), "ffi": r.get("first_fire_index"), "latched": r.get("latched")}

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
