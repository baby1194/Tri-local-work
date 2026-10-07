#!/usr/bin/env python3
"""Pick one Secure H100 from `lium ls --format json` on stdin. Print huid."""
import json, os, sys

min_vram = int(os.environ.get("MIN_VRAM", "80"))
min_disk = int(os.environ.get("MIN_DISK", "200"))
min_dl = float(os.environ.get("MIN_DOWNLOAD", "80"))

raw = sys.stdin.read()
try:
    nodes = json.loads(raw)
except json.JSONDecodeError:
    sys.stderr.write("pick_node: lium ls did not return JSON\n")
    sys.exit(2)
if isinstance(nodes, dict):
    nodes = nodes.get("nodes") or nodes.get("data") or []
if not isinstance(nodes, list) or not nodes:
    sys.stderr.write("pick_node: no nodes in listing\n")
    sys.exit(3)

ok = []
for n in nodes:
    vram = n.get("vram_gb") or 0
    disk = n.get("disk_gb") or n.get("disk_total_gb") or 0
    if vram < min_vram or disk < min_disk:
        continue
    ok.append(n)
if not ok:
    ok = list(nodes)

# prefer single-GPU nodes: multi-GPU providers often forbid GPU splitting (can't rent just 1),
# so a gpu_count==1 node is reliably rentable. Fall back to all if none are single-GPU.
single = [n for n in ok if (n.get("gpu_count") or 1) == 1]
ok = single or ok

fast = [n for n in ok if (n.get("download_mbps") or 0) >= min_dl]
pool = fast or ok
pool.sort(key=lambda n: (
    float(n.get("price_per_gpu_hour") or n.get("price_per_hour") or 99),
    -(float(n.get("download_mbps") or 0)),
    -(float(n.get("disk_gb") or 0)),
))
pick = pool[0]
meta = {
    "huid": pick.get("huid"),
    "id": pick.get("id"),
    "gpu_type": pick.get("gpu_type"),
    "gpu_count": pick.get("gpu_count"),
    "vram_gb": pick.get("vram_gb"),
    "price_per_hour": pick.get("price_per_hour"),
    "country": pick.get("country"),
    "city": pick.get("city"),
    "tier": pick.get("tier"),
    "disk_gb": pick.get("disk_gb"),
    "download_mbps": pick.get("download_mbps"),
    "ram_gb": pick.get("ram_gb"),
}
sys.stderr.write("pick_node: " + json.dumps(meta) + "\n")
huid = pick.get("huid") or pick.get("id")
if not huid:
    sys.stderr.write("pick_node: chosen row has no huid\n")
    sys.exit(4)
print(huid)
json.dump(meta, open(os.environ["LOCAL_OUT"] + "/node.json", "w"), indent=2)
