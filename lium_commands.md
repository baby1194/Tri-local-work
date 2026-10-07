# Lium pod control (CLI 0.7.0)

Flags below are from `lium --help` / `lium <cmd> --help` on this machine (`/home/Trustvs/.local/bin/lium`, version 0.7.0). Billing starts at deploy and runs per second until `lium rm`. There is no minimum.

Scripts must target a pod by **name or huid**, never by the `lium ps` row number. A row number is only valid in the same shell, for 10 minutes, while that pod is still listed. `lium rm` with no TTY (this agent) requires `--yes`.

`lium up` has **no** `--tier` flag. `--gpu H100` alone can rent a Spot node. List Secure first, then pass that node's huid.

## 0. Account

```bash
lium whoami
lium balance
lium balance --format json
lium ssh-keys list
lium ssh-keys sync          # register local ~/.ssh pubkeys before the first rent
```

## 1. Find a 1× H100 80GB Secure node

```bash
lium ls --gpu H100 --count 1 --min-vram 80 --tier secure --country US --max-price 2.00
lium ls --gpu H100 --count 1 --min-vram 80 --tier secure --country US --format json
```

`--tier spot` is reclaimable. Do not use it for a multi-hour GCG run.

Templates (Hopper = H100/H200). Pick an id from this before `--template_id` or `--image`:

```bash
lium templates pytorch --arch hopper
lium templates pytorch --arch hopper --format json
```

## 2. Rent

Auto-terminate is mandatory. `--ttl` is scheduled as soon as the pod exists, including if it never becomes ready. `--budget` is armed only after the pod is ready, so pair it with `--ttl`. The earlier deadline wins.

```bash
lium up <NODE_HUID> \
  --name gcg-h100 \
  --count 1 \
  --ttl 6h \
  --budget 12 \
  --timeout 900 \
  --verify-gpus \
  --strict-gpus \
  --yes \
  --no-ssh \
  --json
```

`<NODE_HUID>` is the `huid` (or UUID) from `lium ls --format json`, not a row number from an old listing.

Useful `up` flags if the default image is wrong:

```bash
lium up <NODE_HUID> --name gcg-h100 --image pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel \
  --ttl 6h --budget 12 --yes --json
# or
lium up <NODE_HUID> --name gcg-h100 --template_id <ID_FROM_lium_templates> \
  --ttl 6h --budget 12 --yes --json
```

`--json` implies `--no-ssh`. Progress is on stderr. A ready pod is one JSON object on stdout.

If `--timeout` fires **after** the rent, the pod is already billing. Name it and `lium rm` it. `--strict-gpus` removes the pod when `nvidia-smi` count ≠ billed count.

## 3. Status and cost

```bash
lium ps --wide
lium ps gcg-h100 --format json
lium describe gcg-h100
lium describe gcg-h100 --json
lium spend
lium spend --format json          # .burn_per_hour, .runway_hours
lium schedules list
```

`lium ps --filter status=RUNNING --filter name=gcg-h100`

## 4. Run commands

`lium exec` returns the remote exit code. `--detach` returns immediately (exit 0) after `nohup`.

```bash
lium exec gcg-h100 "nvidia-smi"
lium exec gcg-h100 --json "python -c 'import torch; print(torch.cuda.get_device_name(0))'"

# long job: GCG
lium exec gcg-h100 -d --log /workspace/gcg.log --script /workspace/gcg.py
# or
lium exec gcg-h100 -d --log /workspace/gcg.log \
  "python /workspace/gcg.py"

# follow that log (container `lium logs` is the pod logger, not the detach file)
lium exec gcg-h100 "tail -n 50 /workspace/gcg.log"
```

Interactive shell (human, not this agent):

```bash
lium ssh gcg-h100
```

Env on one shot:

```bash
lium exec gcg-h100 -e HF_HOME=/workspace/hf "huggingface-cli download Qwen/Qwen3.8-27B"
```

## 5. Files

Upload a tree (resumes; re-run the same command):

```bash
lium rsync gcg-h100 ./local-work/p3-009/toolkit /workspace/toolkit --progress \
  --exclude '__pycache__' --exclude '*.pyc'
```

Default remote path is `/root/<local-dir-name>`. Pass an absolute remote path as the third argument.

Single file:

```bash
lium scp gcg-h100 ./local-work/p3-009/toolkit/gcg_colab_tracka_stamp.py /workspace/gcg.py
```

Download results **before** `rm`:

```bash
mkdir -p local-work/p3-009/lium-gcg
lium scp gcg-h100 /workspace/gcg.log ./local-work/p3-009/lium-gcg/ -d
lium scp gcg-h100 /workspace/suffix.txt ./local-work/p3-009/lium-gcg/ -d
```

`lium rsync` only pushes local → pod. `lium scp -d` pulls pod → local. Pod-to-pod is `lium cp SRC:/path DST:/path`.

## 6. Move the deadline

```bash
lium rm gcg-h100 --in 2h          # schedule, do not remove now
lium rm gcg-h100 --at "today 23:00"
lium schedules list
lium schedules rm <index>         # cancel a scheduled removal
```

## 7. Terminate

Confirm the name, pull artifacts, then remove. This is irreversible.

```bash
lium ps --filter name=gcg-h100 --format json
lium scp gcg-h100 /workspace/gcg.log ./local-work/p3-009/lium-gcg/ -d
lium rm gcg-h100 --yes --name-only --format json
lium ps --filter name=gcg-h100
lium spend
```

`lium rm --all --yes` kills every pod on the account. Do not use it while anything else is rented.

## 8. Intended GCG sequence

Pod name `gcg-h100`. TTL and budget are the cost backstop if this session dies.

```bash
lium ls --gpu H100 --count 1 --min-vram 80 --tier secure --country US --format json
lium up <NODE_HUID> --name gcg-h100 --count 1 --ttl 8h --budget 15 \
  --verify-gpus --strict-gpus --yes --json
lium ps gcg-h100 --format json
lium exec gcg-h100 "nvidia-smi"
lium rsync gcg-h100 ./local-work/p3-009/toolkit /workspace/toolkit --progress
lium exec gcg-h100 -d --log /workspace/gcg.log "python /workspace/toolkit/gcg_colab_tracka_stamp.py"
# when finished:
lium scp gcg-h100 /workspace/gcg.log ./local-work/p3-009/lium-gcg/ -d
lium rm gcg-h100 --yes --name-only --format json
```

The public weights to load on the pod are `Qwen/Qwen3.8-27B` (bf16). `Qwen/Qwen3.8-27B-TEE` is the Chutes API name and is not a downloadable checkpoint.
