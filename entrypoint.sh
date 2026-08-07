#!/bin/bash
# Entrypoint for the self-built official ComfyUI image.
#
# Dependency strategy (aligned with the battle-tested yanwk/comfyui-boot model):
#   PIP_USER=true -> every pip install (entrypoint AND ComfyUI-Manager) lands
#   in ~/.local (user site), which is mounted on persistent storage, so node
#   dependencies survive container recreates. The venv is created with
#   include-system-site-packages=true (pyvenv.cfg), which enables the user
#   site; sys.path order (venv site-packages BEFORE user site) guarantees the
#   image-baked cu130 torch can never be shadowed by a PyPI torch dragged in
#   as a transitive dependency.
set -e
cd /app/ComfyUI

export PIP_USER=true
export PIP_ROOT_USER_ACTION=ignore
export PIP_NO_BUILD_ISOLATION=1

USER_SITE="$HOME/.local/lib/python3.12/site-packages"
DEPS_HASH_FILE="$HOME/.local/.deps_hash"
export PATH="${PATH}:$HOME/.local/bin"

# ensure ComfyUI-Manager (custom_nodes mount may start empty)
if [ ! -d custom_nodes/ComfyUI-Manager ]; then
  echo "[entrypoint] installing ComfyUI-Manager"
  git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
  pip install --user -r custom_nodes/ComfyUI-Manager/requirements.txt
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
  echo "[entrypoint] installing node dependencies to persistent user site: $USER_SITE"
  mkdir -p "$USER_SITE"
  FAILED=0
  for req in custom_nodes/*/requirements.txt; do
    [ -f "$req" ] || continue
    echo "[entrypoint] pip install --user -r $req"
    # filter out comments, git+ URLs (lazy/niche deps like sam2 — cloned from
    # GitHub at install time, unreliable from some networks; Impact-Pack etc.
    # import fine without them and ComfyUI-Manager installs them on demand)
    # and torch-family lines (baked cu130 must win; the sys.path order already
    # guarantees it, this just avoids the download)
    grep -v -E '^(#|git\+|torch|torchvision|torchaudio)' "$req" > /tmp/req_filtered.txt || true
    pip install --user -q -c /venv/constraints.txt -r /tmp/req_filtered.txt \
      || { echo "[entrypoint] WARN failed: $req"; FAILED=1; }
  done
  echo "[entrypoint] pip install --user extras (ReActor family)"
  pip install --user -q -c /venv/constraints.txt insightface facexlib \
    || { echo "[entrypoint] WARN extras 1/2"; FAILED=1; }
  pip install --user -q -c /venv/constraints.txt --no-deps gfpgan basicsr \
    || { echo "[entrypoint] WARN extras 2/2"; FAILED=1; }
  if [ "$FAILED" = "0" ] && [ -n "$HASH" ]; then
    echo "$HASH" > "$DEPS_HASH_FILE"
    echo "[entrypoint] deps installed — hash recorded"
  else
    echo "[entrypoint] some installs failed — will retry on next start"
  fi
else
  echo "[entrypoint] node deps up to date (user site, hash match)"
fi

# belt-and-suspenders: purge any torch-family that a transitive dependency
# dragged into the user site (should never shadow the baked cu130 thanks to
# sys.path order, but keep the user site clean anyway). Idempotent.
rm -rf "$USER_SITE"/torch "$USER_SITE"/torchvision "$USER_SITE"/torchaudio \
       "$USER_SITE"/torchgen "$USER_SITE"/triton "$USER_SITE"/nvidia \
       "$USER_SITE"/torch-*.dist-info "$USER_SITE"/torchvision-*.dist-info \
       "$USER_SITE"/torchaudio-*.dist-info "$USER_SITE"/triton-*.dist-info \
       "$USER_SITE"/nvidia_*.dist-info "$USER_SITE"/torch*.libs 2>/dev/null || true

# basicsr/gfpgan import the removed torchvision API -> compat shim (idempotent)
SHIM="/venv/lib/python3.12/site-packages/torchvision/transforms/functional_tensor.py"
if [ ! -f "$SHIM" ]; then
  mkdir -p "$(dirname "$SHIM")"
  echo "from torchvision.transforms.functional import rgb_to_grayscale" > "$SHIM"
  echo "[entrypoint] wrote torchvision functional_tensor shim"
fi

exec python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS}
