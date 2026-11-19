# herro — builds

[HERRO](https://github.com/lbcb-sci/herro) 是一个 haplotype-aware 的深度学习工具，用于 Nanopore 超长读段（ultralong reads）的错误校正。

本仓库**不开发 herro 源码**，而是：

1. 定时自动同步上游 [`lbcb-sci/herro`](https://github.com/lbcb-sci/herro) 的源码改动；
2. 为每次源码变更构建并发布：
   - **Linux amd64 二进制**（含 minimap2、模型 `model_R10_v0.1.pt`）→ GitHub Releases
   - **Docker 镜像** → `ghcr.io/wwz33/herro`
   - **Singularity/Apptainer `.sif`** → GitHub Releases

模型文件 `model_R10_v0.1.pt`（R10.4.1）随仓库分发，并打包进每个 Release。

## 产物

- Docker: `docker pull ghcr.io/wwz33/herro:latest`
- 二进制 / `.sif` / 模型: <https://github.com/WWz33/herro/releases>

## 构建说明

- 基于 `nvidia/cuda:12.4.1-cudnn` + libtorch `2.4.0+cu124`（对应 `tch 0.17.0`）。
- 编译时设置 `LIBTORCH` 绝对路径以及 `-Wl,-rpath,<libtorch/lib>`，避免运行时误加载宿主机 conda 的 PyTorch。
- 补了 `libnvrtc-builtins.so.12.4` 的 SONAME 软链，否则 NVRTC 在运行时按 SONAME `dlopen` 会失败（报 `failed to open libnvrtc-builtins.so.12.4`）。

## 工作流

- `.github/workflows/sync-upstream.yml`：每天定时（也支持手动）同步上游 `src/`、`Cargo.toml`、`scripts/` 等，若有变更则提交并触发构建。
- `.github/workflows/build.yml`：构建并发布上述三类产物（支持手动 `workflow_dispatch` 与 `v*` tag 触发）。

## 使用

```shell
# Docker（需要 NVIDIA Container Toolkit）
docker run --rm --gpus all ghcr.io/wwz33/herro:latest --help

# Singularity
singularity run --nv herro.sif inference ...
```

原始用法与参数见 [上游 README](https://github.com/lbcb-sci/herro#usage)。
