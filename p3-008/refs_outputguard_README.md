---
base_model: Qwen/Qwen3.5-0.8B
tags:
  - guardrail
  - safety
  - streaming
  - token-classification
pipeline_tag: token-classification
---

# Halo0.8B-StreamGuard-v2a

> ## ⚠️ Not a replacement for StreamGuard-v1
>
> Despite the name, **this model detects *less* harmful content than
> [Halo0.8B-StreamGuard-v1](https://huggingface.co/ash-astro/Halo0.8B-StreamGuard-v1)**
> and should not be swapped in for it.
>
> | | v1 | v2a |
> |---|---|---|
> | BeaverTails recall | 67.40% | **57.36%** |
> | SafeRLHF recall | 68.67% | **59.36%** |
> | onset recall, natural held-out set | 59.20% | **50.50%** |
> | six-benchmark macro F1 | 72.56 | 72.73 |
>
> It is published as a **research artifact and negative result**, not as a release.
> Its headline in-distribution numbers are largely distribution matching — see
> [Read the numbers correctly](#read-the-numbers-correctly).

A streaming output guard: a binary token head over a Qwen3.5-0.8B backbone that scores
**every position of a model response**, so a single forward pass yields a verdict for every
prefix. It exists to catch a response that *starts* safe and *becomes* harmful partway
through — the "onset" case a whole-response classifier cannot express.

v2a is a continuation fine-tune of v1 on a corrective corpus of matched safe/unsafe response
pairs. It was an experiment in whether such pairs teach the distinction. **In distribution
they do, dramatically. They did not generalise.**

## Read the numbers correctly

Evaluated on two onset sets, both held out from training:

| | v1 | v2a |
|---|---|---|
| **synthetic gate** — pair discrimination | 13.86% | **87.95%** |
| **synthetic gate** — onset recall | 59.64% | **98.49%** |
| **natural probe** — onset recall | **59.20%** | **50.50%** |
| **natural probe** — late-crossing recall | 23.1% | 22.0% |

The gate was built by the same generation pipeline as the training corpus; the natural probe
was not. The decision rule was written down before either was measured: *if gate recall jumps
while natural recall holds, the capability is real; if natural recall does not hold, it is
distribution matching.* **Natural recall fell.** So the 13.86% → 87.95% figure measures
fit to the training distribution, not a general onset-detection capability.

Six public benchmarks (frozen serving rule, macro F1):
WildGuard +4.54 · HarmBench +3.41 · XSTest-Response +3.83 ·
Aegis2.0 −2.08 · SafeRLHF −3.50 · BeaverTails −5.21 → **macro 72.56 → 72.73**.

Gains on the over-refusal suites, losses on the missed-harm suites: the corpus was 75%
false-positive-side and taught the model to fire less. Precision rose, recall fell, and the
two roughly cancelled.

Recalibration does not fix it: sweeping every rule × threshold *with full label knowledge*
caps the macro at **73.50**.

## Usage

The head is binary (`{safe: 0, unsafe: 1}`) and **requires latching** — once it fires it
stays fired for the rest of the response (`serving_requires_latching: true`).

```python
import torch
from transformers import AutoModel, AutoTokenizer

tok = AutoTokenizer.from_pretrained("ash-astro/Halo0.8B-StreamGuard-v2a")
backbone = AutoModel.from_pretrained("ash-astro/Halo0.8B-StreamGuard-v2a", subfolder="backbone")
head = torch.nn.Linear(1024, 2)
head.load_state_dict(torch.load("token_head.pt", map_location="cpu"))  # from the repo root

ids = tok(prompt, add_special_tokens=False)["input_ids"]
resp = tok(response, add_special_tokens=False)["input_ids"]
h = backbone(input_ids=torch.tensor([ids + resp]))[0]
p_unsafe = torch.softmax(head(h).float(), -1)[0, len(ids):, 1]   # one probability per response token
```

Decision rule used for every number on this page (latched, no warmup):

```
fire  iff  max(p_unsafe) >= 0.975   OR   three consecutive tokens >= 0.84
```

**Release invariant.** Any replacement rule must remain able to fire on a harmful response
of **1–3 tokens**. Smoothed rules (`rolling mean`, `k-of-n`, warmup) are *structurally
incapable* of firing on a 3-token response, however confident the model is — a short
compliance like "Sure, here:" would be undetectable. This is not a tuning preference; a rule
that violates it has a silent blind spot.

## Training

- Continuation fine-tune from v1 — backbone **and** head initialised from it.
- 12,931 rows: 8,931 generated corrective pairs + 4,000 replayed v1 training rows.
- Tokenised **unpacked**. On this hybrid backbone 18 of 24 layers leak recurrent state
  across packed sequence boundaries, so packing silently corrupts per-token labels.
- 2 epochs, lr 3e-5, effective batch 32, `max_length` 2048, bf16 autocast, FlashAttention-2.
- Checkpoint 500 of 810 (epoch 1.24), chosen by false-positive-rate criteria on a
  v1-distribution dev slice — **not** by peak eval F1, which oscillated ~2 points between
  adjacent checkpoints.
- Never trained on: the evaluation splits above, the onset gate, the natural probe, or any
  of the six public benchmarks.

## Known defects

1. **The `hard_positive_fn` bucket is confounded.** It is 25% of the corpus and exists to
   supply BeaverTails/SafeRLHF recall — the two suites that lost ~10 points of recall each.
   It is also the only bucket whose *generator* correlates perfectly with its label (safe
   twins from an aligned model, unsafe twins from an unrestricted one), while the other
   three buckets are counterbalanced. Leading hypothesis for the regression.
2. **Onset overshoot.** 49.8% of unsafe rows carry a delayed onset, against a 30–40% design
   target — plausibly teaching suspicion of safe-looking prefixes.
3. **Narrow.** 12,931 rows cover only 753 distinct seed behaviours.

## Provenance

`token_head.pt` md5 `fe37ff4a7ff2982ef9878ba690345305` ·
`backbone/model.safetensors` md5 `90a1ea2d7eb32fd9b80d298645ea629c`
