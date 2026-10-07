# p3-009 toolkit — live rebuilt stack

Ground truth = `gwscore.py` (OpenClaw gateway: input guard + agent + output guard, then judge).
Blocks iff classify `status == "HARMFUL"`.

## Pipeline
input `halo-guard` → Qwen3.8-27B-TEE (OpenClaw, thinking off) → output `halo-output-guard` → judge
- INPUT: `astroboi-halo-guard.chutes.ai/v1/classify`, role `input`
- OUTPUT: `astroboi-halo-output-guard.chutes.ai/v1/classify`, role `output` (response-only in p3-008; re-verify)
- Guard HTTP 503 → question errors = 0 (`evaluationFailureAction: error`)

## Files
- `_common.py` — endpoints/helpers (reads `tri-check/.env` + current `questions.json`)
- `warmth.py` — ping both classify URLs **and `/health` revisions** (this challenge: input `98dab108`, output `d3df0933`; Hub `a2aea9d9` is next week)
- `probe.py <tpl.json|-> [input|output]` — per-Q guard status
- `canary_input.py` — Phase 0.3/0.4 input canaries
- `characterize_outguard.py` — Phase 0.5 output-guard sweep
- `gwscore.py <tpl.json> [Qids|-] [n]` — REAL gateway + judge
- `gwcapture.py <tpl.json> [Qids|-] [n]` — gateway + dump-on-block text
- `gwdump.py` / `pipe.py` / `proxy.py` — inspect / optimistic / sysprompt proxy

Captures: `local-work/p3-009/captures/`
Dumps: `tri-claw/docker/eval-fixtures/home/node/.openclaw/blocked-outputs/`
