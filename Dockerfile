# Official ComfyUI (github.com/Comfy-Org/ComfyUI) self-built image for TrueNAS Scale 25.10
# - CUDA 12.8.1 runtime  -> works with TrueNAS 25.10 bundled driver (570.172.08, CUDA 12.8 max)
# - torch 2.11.0+cu128   -> newest cu128 line, native sm_120 kernels for RTX 5090/5080/5070
# - Python 3.12          -> matches the custom-node ecosystem; torch 2.11.0 cu128 has cp312 wheels
# Build (as root, TrueNAS WebUI Shell):  docker build -t comfyui-official:cu128-20260805 .
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# system deps: python 3.12, git, ffmpeg (video workflows), GL (custom nodes), curl
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv git curl ca-certificates \
        ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/* \
    && python3 --version

# torch / torchvision / torchaudio from the cu128 index (latest stable in the cu128 line)
# venv is REQUIRED: Ubuntu 24.04 system python is PEP 668 externally-managed
RUN python3 -m venv /venv
ENV PATH=/venv/bin:$PATH
RUN pip install --upgrade pip wheel setuptools \
    && pip install \
        torch==2.11.0 \
        torchvision \
        torchaudio \
        --index-url https://download.pytorch.org/whl/cu128 \
    && python3 -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"

# Official ComfyUI from github.com/Comfy-Org/ComfyUI
WORKDIR /app
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI.git /app/ComfyUI \
    && pip install -r /app/ComfyUI/requirements.txt

# ComfyUI-Manager (official) — kept in the image; entrypoint re-installs if the
# custom_nodes mount does not provide it
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git /app/ComfyUI/custom_nodes/ComfyUI-Manager \
    && pip install -r /app/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8188
VOLUME ["/app/ComfyUI/models", "/app/ComfyUI/input", "/app/ComfyUI/output", "/app/ComfyUI/user", "/app/ComfyUI/custom_nodes", "/root/.cache"]
ENV CLI_ARGS=""
ENTRYPOINT ["/entrypoint.sh"]
