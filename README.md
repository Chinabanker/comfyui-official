# ComfyUI (Official Source) — CUDA 13.0 Docker Image

Self-built image from the **official Comfy-Org/ComfyUI** source code, running the **cu130 line of PyTorch (2.13.0+cu130)**. Optimized for **TrueNAS SCALE 26+** and any Linux host with an NVIDIA driver that supports CUDA 13.0.

中文说明见 [README.zh.md](README.zh.md)

## ✨ Highlights

- **Official ComfyUI** ([github.com/Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI)) pinned to **v0.31.1** + **ComfyUI-Manager** (official)
- **PyTorch 2.13.0+cu130** — the cu130 line with native **sm_120** kernels (RTX 50 series), plus full support for RTX 30/40 series
- **CUDA 13.0.3 runtime** — fixes the unfixable Blackwell (sm_120) cuBLAS bugs in the CUDA 12.8 line (black images / mosaic artifacts / illegal memory access)
- **comfy-aimdo 0.4.13** — DynamicVRAM with NVML pressure awareness (model reload/regression fixes)
- **Python 3.12** — maximum compatibility with the custom-node ecosystem
- **gcc/g++/python3-dev pre-installed** — required for Triton JIT compilation on cu130
- No xFormers by default (recommended for Blackwell GPUs; see `CLI_ARGS`)
- Entrypoint **auto-installs custom node dependencies** at startup (idempotent, survives container recreates)
- Runs as root with NVIDIA GPU passthrough

## ⚙️ Requirements

| Requirement | Detail |
|---|---|
| GPU | NVIDIA **RTX 30 / 40 / 50** series (see [GPU compatibility](#gpu-compatibility)) |
| Driver | Must support **CUDA 13.0** — check `nvidia-smi` → "CUDA Version: 13.0" or higher (Linux driver ≥ 590 branch) |
| TrueNAS SCALE 26 | ✅ bundled driver 590.44.01 (CUDA 13.0) |
| TrueNAS SCALE 25.10 or older | ❌ bundled driver 570.x too old for CUDA 13.0 — **must upgrade to TrueNAS 26** (see below) |
| Runtime | Docker + NVIDIA Container Toolkit, or TrueNAS Apps service |

> ⚠️ **TrueNAS 25.10 users:** the bundled driver (570.172.08) only supports CUDA 12.8. The CUDA 12.8 line has an **unfixable cuBLAS bug on Blackwell (sm_120)** GPUs (RTX 50 series) that causes black images / mosaic artifacts / illegal memory access in ComfyUI. The `cu128` tag has been **removed** — please upgrade to TrueNAS 26 (driver 590.x) to use this image.

## 🏷️ Tags

| Tag | Description |
|---|---|
| `cu130` | Rolling tag, rebuilt when upstream ComfyUI changes |
| `cu130-YYYYMMDD` | Dated builds (retained for 7 days) |

## 🚀 Quick Start

### TrueNAS SCALE 26 (Apps)

1. Add the custom app pointing at `chinabanker/comfyui-official:cu130`
2. Mount persistent storage:
   - `/app/ComfyUI/models` → e.g. `/mnt/pool/Comfyui/models`
   - `/app/ComfyUI/output` → e.g. `/mnt/pool/Comfyui/output`
   - `/app/ComfyUI/custom_nodes` → e.g. `/mnt/pool/Comfyui/custom_nodes`
   - `/root/.local` → e.g. `/mnt/pool/Comfyui/deps` (persistent node deps)
3. Enable GPU passthrough
4. Start, then open `http://<host>:8188`

### Docker CLI

```bash
docker run -d --gpus all \
  -p 8188:8188 \
  -v /mnt/pool/Comfyui/models:/app/ComfyUI/models \
  -v /mnt/pool/Comfyui/output:/app/ComfyUI/output \
  -v /mnt/pool/Comfyui/custom_nodes:/app/ComfyUI/custom_nodes \
  -v /mnt/pool/Comfyui/deps:/root/.local \
  -e CLI_ARGS="--listen 0.0.0.0 --port 8188" \
  chinabanker/comfyui-official:cu130
```

## ⚙️ CLI_ARGS

The entrypoint runs `python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS}`. Defaults are the clean, stable configuration — **no workaround flags needed** on cu130:

```bash
# recommended (stable default)
CLI_ARGS=""

# example: extra options
CLI_ARGS="--preview-method none"
```

Notes:
- `--lowvram` / `--force-fp32` / `--disable-dynamic-vram` workarounds from the cu128 era are **not needed** on cu130 — the Blackwell cuBLAS bug is fixed at the CUDA level
- DynamicVRAM (comfy-aimdo) handles co-existence with other GPU apps (e.g. Ollama) automatically
- On RTX 50 series, consider **NVFP4 model variants** (e.g. FLUX.2 Klein) for 2.5× speedup and 60% lower VRAM

## 📦 What's Pre-installed

- PyTorch 2.13.0+cu130, torchvision, torchaudio (pinned in `/venv/constraints.txt`)
- comfy-aimdo 0.4.13, comfy-kitchen 0.2.26
- Custom-node ecosystem: opencv-python, ultralytics, segment-anything, insightface, facexlib, onnxruntime, onnx, einops, spandrel, matplotlib, dill, piexif, transformers, accelerate, diffusers, timm, kornia, scikit-image, scikit-learn, scipy, pandas, safetensors, sentencepiece, tokenizers, albumentations, gguf, av, imageio, imageio-ffmpeg, omegaconf, fvcore, iopath, numexpr, psutil
- gfpgan/basicsr (--no-deps) + torchvision compat shim
- gcc/g++, python3-dev, ffmpeg, GL libraries

## 🛠️ Build Locally

```bash
docker build -t comfyui-official:cu130 . \
  --build-arg PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple   # optional mirror
```

## GPU Compatibility

| GPU | Architecture | cu130 support |
|---|---|---|
| RTX 30 series | Ampere (sm_86/89) | ✅ (driver ≥ 590) |
| RTX 40 series | Ada (sm_89) | ✅ (driver ≥ 590) |
| RTX 50 series | Blackwell (sm_120) | ✅ **recommended** (native sm_120 kernels, fixes cu128 bugs) |

## 📄 License & Upstream

- ComfyUI: [GPL-3.0](https://github.com/Comfy-Org/ComfyUI/blob/master/LICENSE)
- This repo only contains build files (Dockerfile, entrypoint, CI) — no vendored ComfyUI code
- **Source / Issues**: [github.com/Chinabanker/comfyui-official](https://github.com/Chinabanker/comfyui-official) — report bugs, request features, or check the build pipeline
