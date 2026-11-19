# syntax=docker/dockerfile:1

# ---- Stage: devel (compile) ----
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 AS devel

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq \
      wget curl unzip git build-essential pkg-config zlib1g-dev zstd ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# minimap2
RUN git clone --depth=1 https://github.com/lh3/minimap2.git /minimap2-src \
    && make -C /minimap2-src -j"$(nproc)"

# Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# libtorch 2.4.0+cu124 (matches tch 0.17.0 / herro v0.1.1)
RUN curl -fL --retry 3 -o /tmp/libtorch.zip \
      "https://download.pytorch.org/libtorch/cu124/libtorch-cxx11-abi-shared-with-deps-2.4.0%2Bcu124.zip" \
    && unzip -q /tmp/libtorch.zip -d / \
    && rm -f /tmp/libtorch.zip \
    && test -f /libtorch/include/torch/csrc/api/include/torch/torch.h

# NVRTC dlopens this by SONAME; the archive ships it without the version suffix.
RUN ln -sf /libtorch/lib/libnvrtc-builtins.so /libtorch/lib/libnvrtc-builtins.so.12.4

ENV LIBTORCH=/libtorch
ENV LD_LIBRARY_PATH="/libtorch/lib:${LD_LIBRARY_PATH}"

# Build from the checked-out source (synced from upstream by CI).
WORKDIR /src
COPY Cargo.toml Cargo.lock* ./
COPY src ./src
RUN RUSTFLAGS="-C link-arg=-Wl,-rpath,/libtorch/lib" \
      cargo build --release

# ---- Stage: final (runtime) ----
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04 AS final

RUN apt-get update -qq && apt-get install -y -qq \
      libgomp1 zlib1g-dev zstd ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=devel /minimap2-src/minimap2 /usr/local/bin/minimap2
COPY --from=devel /src/target/release/herro /usr/local/bin/herro
COPY --from=devel /libtorch /libtorch
RUN ln -sf /libtorch/lib/libnvrtc-builtins.so /libtorch/lib/libnvrtc-builtins.so.12.4

ENV LIBTORCH=/libtorch
ENV LD_LIBRARY_PATH="/libtorch/lib:${LD_LIBRARY_PATH}"

LABEL org.opencontainers.image.title="herro" \
      org.opencontainers.image.description="Haplotype-aware deep-learning error correction of Nanopore ultralong reads" \
      org.opencontainers.image.source="https://github.com/WWz33/herro"

ENTRYPOINT ["herro"]
CMD ["--help"]
