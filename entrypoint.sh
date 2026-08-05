#!/bin/bash
# Entrypoint for the self-built official ComfyUI image.
# - ensures ComfyUI-Manager exists (custom_nodes may come from a host mount)
# - idempotently installs requirements of all custom nodes present
# - launches ComfyUI on 0.0.0.0:8188 (extra args via CLI_ARGS env, e.g. --disable-xformers)
set -u
cd /app/ComfyUI || exit 1

if [ ! -d custom_nodes/ComfyUI-Manager ]; then
    echo "[entrypoint] installing ComfyUI-Manager"
    git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager \
        && pip install -q -r custom_nodes/ComfyUI-Manager/requirements.txt || true
fi

echo "[entrypoint] installing custom node requirements (idempotent)"
for req in custom_nodes/*/requirements.txt; do
    [ -f "$req" ] || continue
    echo "[entrypoint] pip install -r $req"
    pip install -q -r "$req" || echo "[entrypoint] WARN: failed $req (node may still work)"
done

echo "[entrypoint] launching ComfyUI: python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS:-}"
exec python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS:-}
