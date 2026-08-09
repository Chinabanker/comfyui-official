#!/bin/bash
# Install the prebuilt SageAttention 2.2.0 wheel (cu130 stack) into the container.
#
# Requirements (this image's stack):
#   - torch 2.13.0+cu130, CUDA 13.0, Python 3.12, linux x86_64
#   - RTX 50 series (sm_120) — compiled with NVCC 13.0.88, arch sm_120a
#
# Usage:
#   Run INSIDE the comfyui container (App Shell / docker exec):
#     bash <(curl -sL https://raw.githubusercontent.com/Chinabanker/comfyui-official/main/scripts/install_sageattention.sh)
#
# What it does:
#   - Downloads the wheel from the GitHub release
#   - Installs to the persistent user site (/root/.local) so it survives
#     container recreates (PIP_USER=true matches the image entrypoint)
#   - Restart ComfyUI afterwards; kijai wrappers auto-detect sageattention
set -euo pipefail

VERSION="2.2.0"
TAG="sageattention-${VERSION}-cu130"
WHL="sageattention-${VERSION}-cp312-cp312-linux_x86_64.whl"
URL="https://github.com/Chinabanker/comfyui-official/releases/download/${TAG}/${WHL}"
EXPECTED_SHA256="8609cf377117f249f50f3a2533b1f7ae3aa3c7ec094c89d41ae6fa421bf0a94f"

echo "== SageAttention installer (${VERSION}, cu130/cp312/sm_120) =="

# sanity checks
python3 - <<'PY'
import sys
assert sys.version_info[:2] == (3, 12), f"Python 3.12 required, got {sys.version}"
import torch
print("torch", torch.__version__, "| cuda", torch.version.cuda)
assert torch.version.cuda and torch.version.cuda.startswith("13."), "CUDA 13.x required"
PY

echo "== downloading wheel =="
curl -fL -o "/tmp/${WHL}" "${URL}"
echo "${EXPECTED_SHA256}  /tmp/${WHL}" | sha256sum -c -

echo "== installing to persistent user site =="
PIP_USER=true python3 -m pip install --no-deps "/tmp/${WHL}"

echo "== verifying =="
python3 - <<'PY'
import sageattention
from sageattention import sageattn, sageattn_varlen
print("sageattention", getattr(sageattention, "__version__", "?"), "OK ->", sageattention.__file__)
PY

echo ""
echo "Done. Restart ComfyUI, then in kijai video wrappers (WanVideoWrapper etc.)"
echo "select attention_mode = sageattention."
