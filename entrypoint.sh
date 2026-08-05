#!/bin/bash
# Entrypoint for the self-built official ComfyUI image.
# - ensures ComfyUI-Manager exists (custom_nodes may come from a host mount)
# - ALWAYS installs custom node requirements on boot. pip is fast when the
#   environment is already satisfied (1-3s per node, no downloads), and this
#   guarantees the environment matches the mounted custom_nodes even in
#   freshly recreated containers, where a previous install's packages live in
#   a discarded container layer. (A hash-stamp skip was tried and removed: the
#   stamp persisted in the mount across recreations while the packages it
#   referred to were lost, causing recurring "missing module" node failures.)
set -e
cd /app/ComfyUI

# ensure ComfyUI-Manager (mount may start empty)
if [ ! -d custom_nodes/ComfyUI-Manager ]; then
  echo "[entrypoint] installing ComfyUI-Manager"
  git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
  pip install -r custom_nodes/ComfyUI-Manager/requirements.txt
fi

echo "[entrypoint] installing custom node requirements (idempotent)"
FAILED=0
for req in custom_nodes/*/requirements.txt; do
  [ -f "$req" ] || continue
  echo "[entrypoint] pip install -r $req"
  pip install -q -r "$req" || { echo "[entrypoint] WARN failed: $req"; FAILED=1; }
done

# ReActor-family extras: not in any requirements.txt (installed by the node's
# own installer normally). insightface/facexlib have py3.12 wheels; gfpgan/
# basicsr conflict with the modern torch stack -> install --no-deps.
echo "[entrypoint] pip install extras (ReActor family)"
pip install -q insightface facexlib || { echo "[entrypoint] WARN extras (1/2)"; FAILED=1; }
pip install -q --no-deps gfpgan basicsr || { echo "[entrypoint] WARN extras (2/2)"; FAILED=1; }

# basicsr/gfpgan import the removed torchvision API -> compat shim
SHIM="/venv/lib/python3.12/site-packages/torchvision/transforms/functional_tensor.py"
if [ ! -f "$SHIM" ]; then
  echo "from torchvision.transforms.functional import rgb_to_grayscale" > "$SHIM"
  echo "[entrypoint] wrote torchvision functional_tensor shim"
fi

if [ "$FAILED" != "0" ]; then
  echo "[entrypoint] WARNING: some installs failed; starting anyway"
fi

exec python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS}
