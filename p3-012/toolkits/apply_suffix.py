#!/usr/bin/env python3
"""Write templates/a021_gcg.json from a fetched best.json or suffix.txt."""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
P3010 = HERE.parent
TPL_IN = P3010 / "templates" / "a021_debrief.json"
TPL_OUT = P3010 / "templates" / "a021_gcg.json"
MAX_CHARS = 2000


def load_frame() -> str:
    return json.loads(TPL_IN.read_text())["prompt"]


def load_suffix(path: Path) -> str:
    if path.suffix == ".json":
        d = json.loads(path.read_text())
        if "suffix" in d:
            return d["suffix"]
        if "prompt" in d and d["prompt"].startswith(load_frame()[:40]):
            # full prompt stored; peel the frame prefix
            frame = load_frame()
            p = d["prompt"]
            if p.startswith(frame):
                return p[len(frame) :].lstrip()
        raise SystemExit(f"no suffix in {path}")
    return path.read_text().strip()


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else P3010 / "lium-gcg" / "best.json"
    if not src.exists():
        raise SystemExit(f"missing {src}")
    frame = load_frame()
    if frame.count("{{objective}}") != 1:
        raise SystemExit("frame must contain {{objective}} once")
    suffix = load_suffix(src)
    if not suffix:
        raise SystemExit("empty suffix")
    if "\n" in suffix:
        print("warn: suffix contains newline; keeping it", file=sys.stderr)
    prompt = frame + " " + suffix
    if len(prompt) > MAX_CHARS:
        raise SystemExit(f"prompt is {len(prompt)} chars > {MAX_CHARS}")
    TPL_OUT.write_text(json.dumps({"prompt": prompt}, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {TPL_OUT} chars={len(prompt)} suffix={suffix!r}")


if __name__ == "__main__":
    main()
