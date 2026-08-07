# Official ComfyUI (github.com/Comfy-Org/ComfyUI) self-built image for TrueNAS Scale 26
# - CUDA 13.0.3 runtime  -> works with TrueNAS 26 bundled driver (590.44.01, CUDA 13.0)
# - torch latest+cu130   -> newest cu130 line, native sm_120 kernels for RTX 5090/5080/5070
# - Python 3.12          -> matches the custom-node ecosystem
# Build (as root, TrueNAS WebUI Shell):  docker build -t comfyui-official:cu130 .
# Optional local build with a PyPI mirror:  --build-arg PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
#   (the mirror is NOT baked into the image — it only affects the build steps)
FROM nvidia/cuda:13.0.3-cudnn-runtime-ubuntu24.04

ARG PIP_INDEX_URL

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_BUILD_ISOLATION=1

# system deps: python 3.12, git, ffmpeg (video workflows), GL (custom nodes), curl
# gcc/g++/python3-dev REQUIRED for Triton JIT compilation (PyTorch 2.13+cu130)
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-dev python3-pip python3-venv git curl ca-certificates \
        gcc g++ make \
        ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/* \
    && python3 --version

# torch / torchvision / torchaudio from the cu130 index (latest stable in the cu130 line)
# venv is REQUIRED: Ubuntu 24.04 system python is PEP 668 externally-managed
RUN python3 -m venv /venv
ENV PATH=/venv/bin:$PATH
RUN PIP_INDEX_URL="${PIP_INDEX_URL:-}" pip install --upgrade pip wheel setuptools \
    && PIP_INDEX_URL="${PIP_INDEX_URL:-}" pip install \
        torch \
        torchvision \
        torchaudio \
        --index-url https://download.pytorch.org/whl/cu130 \
    && python3 -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"

# Pin the baked torch family so NO later pip resolution (build or runtime) can
# change/replace it. Every subsequent pip install uses -c constraints.txt.
RUN pip list --format=freeze \
        | awk -F== 'BEGIN{w["torch"]=1;w["torchvision"]=1;w["torchaudio"]=1} $1 in w{print $1"=="$2}' \
        > /venv/constraints.txt \
    && echo "Pinned:" && cat /venv/constraints.txt

# Official ComfyUI from github.com/Comfy-Org/ComfyUI
# Pinned to v0.30.2 (latest release tag as of 2026-08-06)
WORKDIR /app
RUN git clone --depth 1 --branch v0.30.2 https://github.com/Comfy-Org/ComfyUI.git /app/ComfyUI \
    && PIP_INDEX_URL="${PIP_INDEX_URL:-}" pip install -r /app/ComfyUI/requirements.txt \
    && PIP_INDEX_URL="${PIP_INDEX_URL:-}" pip install --upgrade comfy-aimdo==0.4.13

# ComfyUI-Manager (official) — kept in the image; entrypoint re-installs if the
# custom_nodes mount does not provide it
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git /app/ComfyUI/custom_nodes/ComfyUI-Manager \
    && PIP_INDEX_URL="${PIP_INDEX_URL:-}" pip install -r /app/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

# Pre-install heavy/common custom-node dependencies INTO THE IMAGE so that a
# freshly recreated container boots fast. Curated from the battle-tested
# yanwk/comfyui-boot pre-installed list (pak3/pak5), adapted for cu130:
# - insightface/facexlib have py3.12 wheels; gfpgan/basicsr conflict with the
#   modern torch stack -> install --no-deps
# - basicsr/gfpgan import the removed torchvision API -> compat shim
# - all installs carry -c constraints.txt (torch family pinned)
RUN PIP_INDEX_URL="${PIP_INDEX_URL:-}" pip install --no-cache-dir -c /venv/constraints.txt \
        opencv-python ultralytics segment-anything insightface facexlib \
        onnxruntime onnx einops spandrel matplotlib dill piexif \
        transformers accelerate diffusers timm kornia scikit-image \
        scikit-learn scipy pandas safetensors sentencepiece tokenizers \
        albumentations gguf av imageio imageio-ffmpeg omegaconf fvcore \
        iopath numexpr psutil \
    && PIP_INDEX_URL="${PIP_INDEX_URL:-}" pip install --no-cache-dir --no-build-isolation \
           -c /venv/constraints.txt --no-deps gfpgan basicsr \
    && mkdir -p /venv/lib/python3.12/site-packages/torchvision/transforms \
    && printf 'from torchvision.transforms.functional import rgb_to_grayscale\n' \
        > /venv/lib/python3.12/site-packages/torchvision/transforms/functional_tensor.py

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Enable the user site (~/.local) in the venv so PIP_USER installs land on the
# persistent mount. Done LAST so every earlier layer (torch, deps) stays
# cache-reusable; pyvenv.cfg is read at every python invocation.
RUN sed -i 's/include-system-site-packages = false/include-system-site-packages = true/' /venv/pyvenv.cfg \
    && python3 -m site | grep ENABLE_USER_SITE

EXPOSE 8188
VOLUME ["/app/ComfyUI/models", "/app/ComfyUI/input", "/app/ComfyUI/output", "/app/ComfyUI/user", "/app/ComfyUI/custom_nodes", "/root/.cache"]
ENV CLI_ARGS=""
ENTRYPOINT ["/entrypoint.sh"]
