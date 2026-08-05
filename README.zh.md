# ComfyUI(官方源码)— CUDA 12.8 Docker 镜像

基于 **Comfy-Org/ComfyUI 官方源码** 自建,使用 **cu128 系列最新版 PyTorch(2.11.0)**。针对 **TrueNAS SCALE 25.10+** 及任何驱动支持 CUDA 12.8 的 Linux 主机优化。

English: [README.md](README.md)

## ✨ 特性

- 官方 ComfyUI + 官方 ComfyUI-Manager
- **PyTorch 2.11.0+cu128**:cu128 线最新版,原生 **sm_120** 内核(RTX 50 系),完整支持 30/40 系
- **Python 3.12**,自定义节点生态兼容性最佳
- 默认无 xFormers(Blackwell 最佳实践,可用 `CLI_ARGS` 调整)
- 入口脚本启动时自动安装自定义节点依赖(幂等)
- root 运行 + NVIDIA GPU 直通

## ⚙️ 要求

| 项目 | 要求 |
|---|---|
| GPU | NVIDIA **RTX 30/40/50 系**(见兼容表) |
| 驱动 | 需支持 **CUDA 12.8**(`nvidia-smi` 显示 "CUDA Version: 12.8" 及以上,Linux 驱动 ≥ 570 分支) |
| TrueNAS SCALE 25.10 | ✅ 自带驱动 570.172.08(CUDA 12.8) |
| TrueNAS SCALE 24.10 及更早 | ❌ 自带驱动过旧(CUDA 12.4/12.5) |
| 运行时 | Docker + NVIDIA Container Toolkit,或 TrueNAS Apps 服务 |

## 🏷️ 标签

| 标签 | 说明 |
|---|---|
| `cu128` | 滚动标签,定期重建 |
| `cu128-YYYYMMDD` | 日期戳快照 —— 推荐用于可复现部署 |

## 🚀 快速开始(Docker)

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

容器起来后访问 <http://localhost:8188>。

## 🖥️ TrueNAS SCALE(Custom App 安装)

1. Applications → **Installed Applications** → **Add** → **Custom App**
2. Application Name: `comfyui-official`(或其他不重名的名字)
3. Version: `1.0.0`
4. 在 **Custom Docker Compose Configuration** 粘贴:

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

> ⚠️ 首次启动需拉取约 7GB 镜像并为自定义节点安装依赖,请等待几分钟。

## 🌐 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `CLI_ARGS` | 空 | `main.py` 的附加参数,如 `--disable-xformers`、`--lowvram` |
| `NVIDIA_VISIBLE_DEVICES` | `all` | NVIDIA runtime 的 GPU 选择 |

## 📁 数据目录(挂载)

| 宿主机路径 | 容器内路径 | 用途 |
|---|---|---|
| `.../models` | `/app/ComfyUI/models` | 模型(checkpoint/LoRA/VAE 等) |
| `.../input` | `/app/ComfyUI/input` | 输入图片 |
| `.../output` | `/app/ComfyUI/output` | 生成图片 |
| `.../workflows` | `/app/ComfyUI/user/default/workflows` | 已保存的工作流 |
| `.../custom_nodes` | `/app/ComfyUI/custom_nodes` | 自定义节点(重建镜像后保留) |
| `.../user` | `/app/ComfyUI/user` | 用户设置与 Manager 数据库 |
| `.../hf-cache` | `/root/.cache/huggingface/hub` | HuggingFace 模型缓存 |
| `.../torch-cache` | `/root/.cache/torch/hub` | torch hub 缓存 |

## 🎮 GPU 兼容性

CUDA 12.8 / PyTorch cu128 支持以下架构(原生内核或 PTX JIT):

| GPU | 架构 | cu128 |
|---|---|---|
| RTX 50 系(5090/5080/5070) | Blackwell sm_120 | ✅ 原生 |
| RTX 40 系(4090/4080/…) | Ada sm_89 | ✅ |
| RTX 30 系(3090/3080/…) | Ampere sm_80/86 | ✅ |
| RTX 20/16 系 | Turing sm_75 | ✅ |

**驱动注意**:cu128 镜像需要宿主驱动报告 **CUDA ≥ 12.8**。TrueNAS SCALE 需 **25.10 或更新**;Linux 桌面需驱动 ≥ 570 分支。

## 🔄 更新

- **ComfyUI 代码与自定义节点**:用网页里的 **ComfyUI-Manager** 更新(推荐,无需重建容器)。
- **torch / 基础环境**:拉取新的滚动标签并重建容器,或基于 [Dockerfile](https://github.com/Chinabanker/comfyui-official) 本地重建。

## ⚠️ 免责声明

社区维护镜像,基于官方上游源码构建。与 Comfy-Org 无关联,也不代表其立场。维护者不对任何损坏或数据丢失负责。
