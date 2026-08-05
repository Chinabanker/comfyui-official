#!/bin/bash
# Entrypoint for the self-built official ComfyUI image.
# - ensures ComfyUI-Manager exists (custom_nodes may come from a host mount)
# - installs custom node requirements ONLY when they change (hash-stamped,
#   stored in the persistent custom_nodes mount), so restarts are fast
# - self-heals: verifies critical modules at boot even when the stamp matches
#   (an interrupted pip install can leave the env "listed but broken")
set -e
cd /app/ComfyUI

STAMP_FILE="/app/ComfyUI/custom_nodes/.deps_stamp"

compute_hash() {
  find custom_nodes -maxdepth 3 -name requirements.txt -print0 2>/dev/null \
    | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | awk '{print $1}'
}

# critical modules that heavy nodes (Impact-Pack, ReActor, VideoHelperSuite,
# Easy-Use, ollama) need; if any is missing the env is considered broken
check_critical() {
  python3 - <<'PY'
import importlib.util
critical = ["cv2", "ultralytics", "segment_anything", "facexlib", "gfpgan",
            "insightface", "onnxruntime", "einops", "spandrel", "matplotlib"]
missing = [m for m in critical if importlib.util.find_spec(m) is None]
if missing:
    print("MISSING:" + ",".join(missing))
    raise SystemExit(1)
PY
}

install_deps() {
  echo "[entrypoint] installing custom node requirements"
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
  # basicsr/gfpgan still import the removed torchvision API -> compat shim
  SHIM="/venv/lib/python3.12/site-packages/torchvision/transforms/functional_tensor.py"
  if [ ! -f "$SHIM" ]; then
    echo "from torchvision.transforms.functional import rgb_to_grayscale" > "$SHIM"
    echo "[entrypoint] wrote torchvision functional_tensor shim"
  fi
  return "$FAILED"
}

# ensure ComfyUI-Manager (mount may start empty)
if [ ! -d custom_nodes/ComfyUI-Manager ]; then
  echo "[entrypoint] installing ComfyUI-Manager"
  git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
  pip install -r custom_nodes/ComfyUI-Manager/requirements.txt
fi

HASH="$(compute_hash || true)"
STAMP_OK=0
if [ -n "$HASH" ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$HASH" ]; then
  STAMP_OK=1
fi

if [ "$STAMP_OK" = "1" ] && check_critical >/dev/null 2>&1; then
  echo "[entrypoint] custom node requirements unchanged — skipping install (stamp match)"
elif [ "$STAMP_OK" = "1" ]; then
  echo "[entrypoint] stamp matches but critical modules missing — reinstalling (self-heal)"
  rm -f "$STAMP_FILE"
  if install_deps; then
    echo "$HASH" > "$STAMP_FILE"
    echo "[entrypoint] deps repaired — stamp rewritten"
  else
    echo "[entrypoint] some installs failed — will retry on next start"
  fi
else
  echo "[entrypoint] no valid stamp — installing custom node requirements"
  if install_deps; then
    if [ -n "$HASH" ]; then
      echo "$HASH" > "$STAMP_FILE"
      echo "[entrypoint] deps installed — stamp written"
    fi
  else
    echo "[entrypoint] some installs failed — will retry on next start"
  fi
fi

exec python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS}
