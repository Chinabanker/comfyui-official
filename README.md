# ComfyUI (Official Source) — CUDA 12.8 Docker Image

Self-built image from the **official Comfy-Org/ComfyUI** source code, running the **newest cu128 line of PyTorch (2.11.0)**. Optimized for **TrueNAS SCALE 25.10+** and any Linux host with an NVIDIA driver that supports CUDA 12.8.

中文说明见 [README.zh.md](README.zh.md)

## ✨ Highlights

- **Official ComfyUI** ([github.com/Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI)) + **ComfyUI-Manager** (official)
- **PyTorch 2.11.0+cu128** — the newest cu128 build, native **sm_120** kernels (RTX 50 series) and full support for 30/40 series
- **Python 3.12** — maximum compatibility with the custom-node ecosystem
- No xFormers by default (recommended for Blackwell GPUs; see `CLI_ARGS`)
- Entrypoint **auto-installs custom node dependencies** at startup (idempotent)
- Runs as root with NVIDIA GPU passthrough

## ⚙️ Requirements

| Requirement | Detail |
|---|---|
| GPU | NVIDIA **RTX 30 / 40 / 50** series (see [GPU compatibility](#gpu-compatibility)) |
| Driver | Must support **CUDA 12.8** — check `nvidia-smi` → "CUDA Version: 12.8" or higher (Linux driver ≥ 570 branch) |
| TrueNAS SCALE 25.10 | ✅ bundled driver 570.172.08 (CUDA 12.8) |
| TrueNAS SCALE 24.10 or older | ❌ bundled driver too old (CUDA 12.4/12.5) |
| Runtime | Docker + NVIDIA Container Toolkit, or TrueNAS Apps service |

## 🏷️ Tags

| Tag | Description |
|---|---|
| `cu128` | Rolling tag, rebuilt periodically |
| `cu128-YYYYMMDD` | Dated snapshot — recommended for reproducibility |

## 🚀 Quick start (Docker)

```bash
mkdir -p models input output workflows custom_nodes user-data hf-cache torch-cache

docker run -d --name comfyui \
  --runtime nvidia \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e CLI_ARGS=--disable-xformers \
  -p 8188:8188 \
  -v "$(pwd)/models:/app/ComfyUI/models" \
  -v "$(pwd)/input:/app/ComfyUI/input" \
  -v "$(pwd)/output:/app/ComfyUI/output" \
  -v "$(pwd)/workflows:/app/ComfyUI/user/default/workflows" \
  -v "$(pwd)/custom_nodes:/app/ComfyUI/custom_nodes" \
  -v "$(pwd)/user-data:/app/ComfyUI/user" \
  -v "$(pwd)/hf-cache:/root/.cache/huggingface/hub" \
  -v "$(pwd)/torch-cache:/root/.cache/torch/hub" \
  chinabanker/comfyui-official:cu128
```

Open <http://localhost:8188> once the container is up.

## 🖥️ TrueNAS SCALE (Custom App)

1. Applications → **Installed Applications** → **Add** → **Custom App**
2. Application Name: `comfyui-official` (or any unique name)
3. Version: `1.0.0`
4. Paste this into **Custom Docker Compose Configuration**:

```yaml
services:
  comfyui-official:
    image: chinabanker/comfyui-official:cu128
    container_name: comfyui-official
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - CLI_ARGS=--disable-xformers
    ports:
      - "8188:8188"
    volumes:
      - /mnt/<POOL>/Comfyui/models:/app/ComfyUI/models
      - /mnt/<POOL>/Comfyui/input:/app/ComfyUI/input
      - /mnt/<POOL>/Comfyui/output:/app/ComfyUI/output
      - /mnt/<POOL>/Comfyui/workflows:/app/ComfyUI/user/default/workflows
      - /mnt/<POOL>/Comfyui/custom_nodes:/app/ComfyUI/custom_nodes
      - /mnt/<POOL>/Comfyui/user:/app/ComfyUI/user
      - /mnt/<POOL>/Comfyui/hf-cache:/root/.cache/huggingface/hub
      - /mnt/<POOL>/Comfyui/torch-cache:/root/.cache/torch/hub
    restart: unless-stopped
```

> ⚠️ First start pulls ~7 GB and installs your custom nodes' dependencies — allow a few minutes before the UI responds.

## 🌐 Environment variables

| Variable | Default | Description |
|---|---|---|
| `CLI_ARGS` | *(empty)* | Extra args for `main.py`, e.g. `--disable-xformers`, `--lowvram` |
| `NVIDIA_VISIBLE_DEVICES` | `all` | GPU selection for the NVIDIA runtime |

## 📁 Data layout (mounts)

| Host path | Container path | Purpose |
|---|---|---|
| `.../models` | `/app/ComfyUI/models` | checkpoints, LoRAs, VAE, etc. |
| `.../input` | `/app/ComfyUI/input` | input images |
| `.../output` | `/app/ComfyUI/output` | generated images |
| `.../workflows` | `/app/ComfyUI/user/default/workflows` | saved workflows |
| `.../custom_nodes` | `/app/ComfyUI/custom_nodes` | custom nodes (reused across rebuilds) |
| `.../user` | `/app/ComfyUI/user` | user settings & Manager database |
| `.../hf-cache` | `/root/.cache/huggingface/hub` | HuggingFace model cache |
| `.../torch-cache` | `/root/.cache/torch/hub` | torch hub cache |

## 🎮 GPU compatibility

CUDA 12.8 / PyTorch cu128 supports the following architectures (native kernels or PTX JIT):

| GPU | Architecture | cu128 |
|---|---|---|
| RTX 50 series (5090/5080/5070) | Blackwell sm_120 | ✅ native |
| RTX 40 series (4090/4080/…) | Ada sm_89 | ✅ |
| RTX 30 series (3090/3080/…) | Ampere sm_80/86 | ✅ |
| RTX 20/16 series | Turing sm_75 | ✅ |

**Driver caveat**: cu128 images require a host driver reporting **CUDA ≥ 12.8**. On TrueNAS SCALE, that means **25.10 or newer**. On Linux desktops, driver ≥ 570 branch.

## 🔄 Updating

- **ComfyUI code & custom nodes**: use **ComfyUI-Manager** in the web UI (recommended, zero downtime).
- **torch / base environment**: pull the new rolling tag and recreate the container, or rebuild from the [Dockerfile](https://github.com/Chinabanker/comfyui-official) if you build locally.

## ⚠️ Disclaimer

Community-maintained image built from official upstream sources. Not affiliated with or endorsed by Comfy-Org. The maintainer is not liable for any damage or data loss.
