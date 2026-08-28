# ComfyUI（官方源码）— CUDA 13.0 Docker 镜像

基于 **Comfy-Org/ComfyUI 官方源码** 自建的 Docker 镜像，使用 **cu130 系列 PyTorch（2.13.0+cu130）**。针对 **TrueNAS SCALE 26+** 及任何支持 CUDA 13.0 的 Linux 主机优化。

English: [README.md](README.md)

## ✨ 特性

- **官方 ComfyUI**（[github.com/Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI)）锁定 **v0.34.2** + 官方 **ComfyUI-Manager**
- **PyTorch 2.13.0+cu130** — cu130 系列，原生 **sm_120** 内核（RTX 50 系列），同时完整支持 RTX 30/40 系列
- **CUDA 13.0.3 运行时** — 修复 CUDA 12.8 系列在 Blackwell（sm_120）上无法修复的 cuBLAS bug（黑图 / 马赛克 / 非法内存访问）
- **comfy-aimdo 0.4.15** — 具备 NVML 压力感知的 DynamicVRAM（修复模型重载/性能回退问题）
- **Python 3.12** — 与自定义节点生态最大兼容
- **预装 gcc/g++/python3-dev** — cu130 下 Triton JIT 编译必需
- 默认不启用 xFormers（Blackwell GPU 推荐；见 `CLI_ARGS`）
- 入口脚本**自动安装自定义节点依赖**（幂等，容器重建后保留）
- 以 root 运行，支持 NVIDIA GPU 直通

## ⚙️ 环境要求

| 要求 | 说明 |
|---|---|
| GPU | NVIDIA **RTX 30 / 40 / 50** 系列（见 [GPU 兼容性](#gpu-兼容性)） |
| 驱动 | 必须支持 **CUDA 13.0** — 运行 `nvidia-smi` 查看 "CUDA Version: 13.0" 或更高（Linux 驱动 ≥ 590 分支） |
| TrueNAS SCALE 26 | ✅ 内置驱动 590.44.01（CUDA 13.0） |
| TrueNAS SCALE 25.10 或更旧 | ❌ 内置驱动 570.x 太旧，不支持 CUDA 13.0 — **必须升级到 TrueNAS 26**（见下文） |
| 运行时 | Docker + NVIDIA Container Toolkit，或 TrueNAS Apps 服务 |

> ⚠️ **TrueNAS 25.10 用户：** 内置驱动（570.172.08）仅支持 CUDA 12.8。CUDA 12.8 系列在 Blackwell（sm_120）GPU（RTX 50 系列）上存在**无法修复的 cuBLAS bug**，会导致 ComfyUI 黑图 / 马赛克 / 非法内存访问。`cu128` 标签**已移除** — 请升级到 TrueNAS 26（驱动 590.x）后使用本镜像。

## 🏷️ 镜像标签

| 标签 | 说明 |
|---|---|
| `cu130` | 滚动标签，上游 ComfyUI 更新时自动重建 |
| `cu130-YYYYMMDD` | 按日期构建（保留 7 天） |

## 🚀 快速开始

### TrueNAS SCALE 26（Apps）

1. 添加自定义应用，镜像指向 `chinabanker/comfyui-official:cu130`
2. 挂载持久化存储：
   - `/app/ComfyUI/models` → 例如 `/mnt/pool/Comfyui/models`
   - `/app/ComfyUI/output` → 例如 `/mnt/pool/Comfyui/output`
   - `/app/ComfyUI/custom_nodes` → 例如 `/mnt/pool/Comfyui/custom_nodes`
   - `/root/.local` → 例如 `/mnt/pool/Comfyui/deps`（节点依赖持久化）
3. 启用 GPU 直通
4. 启动后访问 `http://<主机IP>:8188`

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

## 🚀 SageAttention（视频生成加速）

本仓库在 [GitHub Release `sageattention-2.2.0-cu130`](https://github.com/Chinabanker/comfyui-official/releases/tag/sageattention-2.2.0-cu130)
发布了**与本镜像完全匹配的 SageAttention 2.2.0 预编译 wheel**：

- torch 2.13.0+cu130 / CUDA 13.0 / Python 3.12 / linux x86_64
- 专为 **sm_120（RTX 50 系列）** 编译（NVCC 13.0.88），含 SageAttention2++ CUDA 内核
  （INT8 QK + FP8 PV）与 Triton varlen 内核
- 源码：[thu-ml/SageAttention](https://github.com/thu-ml/SageAttention) main（v2.2.0）

在运行中的容器内安装（经 `/root/.local` 挂载，容器重建后依然生效）：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Chinabanker/comfyui-official/main/scripts/install_sageattention.sh)
```

安装后**重启 ComfyUI**。kijai 视频节点（WanVideoWrapper、HunyuanVideoWrapper 等）
会自动探测 `sageattention`——在模型加载节点中选择 `attention_mode = sageattention`
即可，RTX 50 系列注意力部分提速约 2-3 倍。

> 提示：自行源码编译需要完整 CUDA 13.0 工具链（`apt-get install cuda-toolkit-13-0`），
> 直接用预编译 wheel 可免去这一步。

## ⚙️ CLI_ARGS

入口脚本运行 `python3 main.py --listen 0.0.0.0 --port 8188 ${CLI_ARGS}`。默认是干净、稳定的配置 — **cu130 上无需任何 workaround 参数**：

```bash
# 推荐（稳定默认）
CLI_ARGS=""

# 示例：附加选项
CLI_ARGS="--preview-method none"
```

说明：
- cu128 时代的 `--lowvram` / `--force-fp32` / `--disable-dynamic-vram` 等 workaround **在 cu130 上不再需要** — Blackwell cuBLAS bug 已在 CUDA 层面修复
- DynamicVRAM（comfy-aimdo）自动处理与其他 GPU 应用（如 Ollama）共存
- RTX 50 系列可考虑使用 **NVFP4 量化模型**（如 FLUX.2 Klein），速度提升 2.5 倍、VRAM 降低 60%

## 📦 预装内容

- PyTorch 2.13.0+cu130、torchvision、torchaudio（锁定于 `/venv/constraints.txt`）
- comfy-aimdo 0.4.15、comfy-kitchen 0.2.26
- 自定义节点生态：opencv-python、ultralytics、segment-anything、insightface、facexlib、onnxruntime、onnx、einops、spandrel、matplotlib、dill、piexif、transformers、accelerate、diffusers、timm、kornia、scikit-image、scikit-learn、scipy、pandas、safetensors、sentencepiece、tokenizers、albumentations、gguf、av、imageio、imageio-ffmpeg、omegaconf、fvcore、iopath、numexpr、psutil
- gfpgan/basicsr（--no-deps）+ torchvision 兼容 shim
- gcc/g++、python3-dev、ffmpeg、GL 库

## 🛠️ 本地构建

```bash
docker build -t comfyui-official:cu130 . \
  --build-arg PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple   # 可选镜像源
```

## GPU 兼容性

| GPU | 架构 | cu130 支持 |
|---|---|---|
| RTX 30 系列 | Ampere (sm_86/89) | ✅（驱动 ≥ 590） |
| RTX 40 系列 | Ada (sm_89) | ✅（驱动 ≥ 590） |
| RTX 50 系列 | Blackwell (sm_120) | ✅ **推荐**（原生 sm_120 内核，修复 cu128 bug） |

## 📄 许可证与上游

- ComfyUI: [GPL-3.0](https://github.com/Comfy-Org/ComfyUI/blob/master/LICENSE)
- 本仓库仅包含构建文件（Dockerfile、entrypoint、CI），不含任何 ComfyUI 代码
- **源码 / 问题反馈**: [github.com/Chinabanker/comfyui-official](https://github.com/Chinabanker/comfyui-official) — 报告 bug、请求功能或查看构建流水线
