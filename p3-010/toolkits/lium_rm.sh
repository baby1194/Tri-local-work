#!/usr/bin/env bash
# Terminate the GCG pod. Irreversible. Requires artifacts unless --force.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$DIR/env.sh"

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [--force]"
  echo "  lium rm $POD_NAME --yes --name-only"
  echo "  refuses if FETCHED is missing, unless --force"
  exit 0
fi

if [[ ! -f "$LOCAL_OUT/pod.json" && "$FORCE" -ne 1 ]]; then
  echo "no pod.json. If a pod is still billed, pass --force after setting POD_NAME." >&2
  lium ps --format json || true
  exit 2
fi

if [[ ! -f "$LOCAL_OUT/FETCHED" && "$FORCE" -ne 1 ]]; then
  echo "no $LOCAL_OUT/FETCHED — run lium_fetch.sh first, or pass --force." >&2
  exit 3
fi

echo "=== removing $POD_NAME ==="
lium ps --filter "name=$POD_NAME" --format json || true
lium rm "$POD_NAME" --yes --name-only --format json
mv "$LOCAL_OUT/pod.json" "$LOCAL_OUT/pod.removed.json" 2>/dev/null || true
echo "=== spend after rm ==="
lium spend --format json || true
lium ps --filter "name=$POD_NAME" || true
echo "removed $POD_NAME"
