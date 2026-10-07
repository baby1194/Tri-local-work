# Real full pipeline via the OpenClaw gateway (input guard + model + output guard), then judge. Parallel.
import json,os,re,urllib.request,concurrent.futures,time,sys
BASE="/home/Trustvs/Ares/Projects/Bittensor/trishool-phase2/tri-check"
env={}
for l in open(BASE+"/.env"):
    if "=" in l and not l.strip().startswith("#"): k,v=l.split("=",1); env[k.strip()]=v.strip()
KEY=env["CHUTES_API_KEY"]; GW=env["OPENCLAW_URL"].rstrip("/"); TOK=env["OPENCLAW_GATEWAY_PASSWORD"]; JUDGE=env["JUDGE_URL"].rstrip("/")
Q=json.load(open(BASE+"/data/questions.json")); Q=Q if isinstance(Q,list) else Q["questions"]
Qby={q["question_id"]:q for q in Q}; OBJS={q["question_id"]:q["objective"] for q in Q}
def _post(url,body,hdr,to=240):
    req=urllib.request.Request(url,json.dumps(body).encode(),{**hdr,"Content-Type":"application/json"})
    for a in range(4):
        try: return json.load(urllib.request.urlopen(req,timeout=to))
        except Exception as e:
            last=e; time.sleep(2*(a+1))
    raise last
def expand(tpl,obj): return re.sub(r"\{\{\s*objective\s*\}\}",obj,tpl,count=1,flags=re.I)
def gateway(prompt):
    r=_post(GW+"/v1/chat/completions",{"model":"openclaw:main","messages":[{"role":"user","content":prompt}]},
            {"Authorization":"Bearer "+TOK,"X-Chutes-Api-Key":KEY})
    return (r.get("choices") or [{}])[0].get("message",{}).get("content") or ""
def judge(qid,prompt,resp):
    q=Qby[qid]; eo="Expected safe behavior:\n"+q.get("expected_safe_behavior","")+"\n\nExpected unsafe (jailbreak) output:\n"+q.get("expected_unsafe_output","")
    r=_post(JUDGE+"/v1/judge/evaluate",{"question":qid,"prompt":prompt,"modelResponse":resp,"toolCalls":[],"expectedOutput":eo},{"X-Chutes-Api-Key":KEY})
    return r.get("judgeVerdict"), r.get("score")
def trial(tpl,qid):
    p=expand(tpl,OBJS[qid]); resp=gateway(p)
    blocked = resp.strip().startswith("Blocked by") or resp.strip()=="" 
    if blocked: return {"qid":qid,"score":0,"tag":"BLOCK","resp":resp[:50]}
    v,s=judge(qid,p,resp); return {"qid":qid,"score":s or 0,"tag":v,"resp":resp[:0]}
def eval_template(tpl, qids=None, samples=1):
    qids=qids or list(OBJS); res={q:[] for q in qids}
    jobs=[(q,i) for q in qids for i in range(samples)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        futs={ex.submit(trial,tpl,q):(q,i) for q,i in jobs}
        for f in concurrent.futures.as_completed(futs):
            q,i=futs[f]
            try: res[q].append(f.result())
            except Exception as e: res[q].append({"qid":q,"score":0,"tag":"ERR"})
    return res
if __name__=="__main__":
    f=sys.argv[1]; tpl=json.load(open(f))["prompt"]
    qids=sys.argv[2].split(",") if len(sys.argv)>2 and sys.argv[2]!="-" else list(OBJS)
    n=int(sys.argv[3]) if len(sys.argv)>3 else 1
    res=eval_template(tpl,qids,n)
    tot=0; line=[]
    for q in ["Q1","Q2","Q3","Q4","Q5","Q6"]:
        if q in res:
            sc=[t["score"] for t in res[q]]; avg=sum(sc)/len(sc); tot+=avg
            line.append(f"{q}={'/'.join(str(x) for x in sc)}")
    print(f"MEAN {tot:.1f}/12 (avg over {n}) | "+"  ".join(line))
