#!/bin/bash
# Entrypoint for the self-built official ComfyUI image.
#
# Dependency strategy (persistent installs):
#   Node dependencies are installed ONCE into a persistent directory on the
#   data mount (/app/ComfyUI/deps) instead of into the ephemeral container
#   layer. A requirements hash is stored next to them. On boot:
#     - hash matches  -> nothing to do (fast boot, even after a container
#                        recreate, because the deps live on the mount)
#     - no hash / hash changed -> (re)install into the mount dir (incremental:
#                        pip --target skips already-satisfied packages)
#   torch/torchvision/torchaudio are EXCLUDED from the target installs so the
#   image-baked cu128 builds always win.
set -e
cd /app/ComfyUI

DEPS_DIR="/app/ComfyUI/deps"
DEPS_HASH_FILE="$DEPS_DIR/.deps_hash"
export PYTHONPATH="$DEPS_DIR:$PYTHONPATH"

# ensure ComfyUI-Manager (custom_nodes mount may start empty)
if [ ! -d custom_nodes/ComfyUI-Manager ]; then
  echo "[entrypoint] installing ComfyUI-Manager"
  git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
  pip install -r custom_nodes/ComfyUI-Manager/requirements.txt
fi

compute_hash() {
  find custom_nodes -maxdepth 3 -name requirements.txt -print0 2>/dev/null \
    | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | awk '{print $1}'
}

HASH="$(compute_hash || true)"

needs_install=0
if [ ! -f "$DEPS_HASH_FILE" ]; then
  needs_install=1
elif [ -n "$HASH" ] && [ "$(cat "$DEPS_HASH_FILE" 2>/dev/null)" != "$HASH" ]; then
  echo "[entrypoint] custom node requirements changed — updating deps"
  needs_install=1
fi

if [ "$needs_install" = "1" ]; then
  echo "[entrypoint] installing node dependencies to persistent dir: $DEPS_DIR"
  mkdir -p "$DEPS_DIR"
  FAILED=0
  for req in custom_nodes/*/requirements.txt; do
    [ -f "$req" ] || continue
    echo "[entrypoint] pip install --target -r $req"
    # filter out comments and torch-family (baked cu128 must win)
    grep -v -E '^(#|torch|torchvision|torchaudio)' "$req" > /tmp/req_filtered.txt || true
    pip install -q --target "$DEPS_DIR" -r /tmp/req_filtered.txt \
      || { echo "[entrypoint] WARN failed: $req"; FAILED=1; }
  done
  echo "[entrypoint] pip install --target extras (ReActor family)"
  pip install -q --target "$DEPS_DIR" insightface facexlib \
    || { echo "[entrypoint] WARN extras 1/2"; FAILED=1; }
  pip install -q --target "$DEPS_DIR" --no-deps gfpgan basicsr \
    || { echo "[entrypoint] WARN extras 2/2"; FAILED=1; }
  if [ "$FAILED" = "0" ] && [ -n "$HASH" ]; then
    echo "$HASH" > "$DEPS_HASH_FILE"
    echo "[entrypoint] deps installed — hash recorded"
  else
    echo "[entrypoint] some installs failed — will retry on next start"
  fi
else
  echo "[entrypoint] node deps up to date (persistent dir, hash match)"
fi

# basicsr/gfpgan import the removed torchvision API -> compat shim (idempotent)
SHIM="/venv/lib/python3.12/site-packages/torchvision/transforms/functional_tensor.py"
if [ ! -f "$SHIM" ]; then
  mkdir -p "$(dirname "$SHIM")"
  echo "from torchvision.transforms.functional import rgb_to_grayscale" > "$SHIM"
  echo "[entrypoint] wrote torchvision functional_tensor shim"
fi

exec python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS}
