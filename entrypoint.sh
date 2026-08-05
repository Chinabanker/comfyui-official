#!/bin/bash
# Entrypoint for the self-built official ComfyUI image.
# - ensures ComfyUI-Manager exists (custom_nodes may come from a host mount)
# - installs custom node requirements ONLY when they change (hash-stamped,
#   stored in the persistent custom_nodes mount), so restarts are fast
set -e
cd /app/ComfyUI

STAMP_FILE="/app/ComfyUI/custom_nodes/.deps_stamp"

compute_hash() {
  find custom_nodes -maxdepth 3 -name requirements.txt -print0 2>/dev/null \
    | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | awk '{print $1}'
}

# ensure ComfyUI-Manager (mount may start empty)
if [ ! -d custom_nodes/ComfyUI-Manager ]; then
  echo "[entrypoint] installing ComfyUI-Manager"
  git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
  pip install -r custom_nodes/ComfyUI-Manager/requirements.txt
fi

HASH="$(compute_hash || true)"
if [ -n "$HASH" ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$HASH" ]; then
  echo "[entrypoint] custom node requirements unchanged — skipping install (stamp match)"
else
  echo "[entrypoint] installing custom node requirements (idempotent)"
  FAILED=0
  for req in custom_nodes/*/requirements.txt; do
    [ -f "$req" ] || continue
    echo "[entrypoint] pip install -r $req"
    pip install -q -r "$req" || { echo "[entrypoint] WARN failed: $req"; FAILED=1; }
  done
  if [ "$FAILED" = "0" ] && [ -n "$HASH" ]; then
    echo "$HASH" > "$STAMP_FILE"
    echo "[entrypoint] deps installed — stamp written"
  else
    echo "[entrypoint] some installs failed — will retry on next start"
  fi
fi

exec python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS}
