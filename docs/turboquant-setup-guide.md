# TurboQuant LLM Stack — Setup Guide

A step-by-step guide to deploying a high-performance local LLM stack using Harbor, llama.cpp with TurboQuant KV cache compression, and Open WebUI. Derived from a working RTX 3070 deployment; includes notes for RTX 3090 and other configurations.

## Prerequisites

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| GPU | NVIDIA RTX 3070 (8 GB) | RTX 3090 (24 GB) |
| RAM | 16 GB | 32 GB |
| Disk | 30 GB free | 60 GB free |
| OS | Windows 11 / Linux | Windows 11 + WSL2 |
| Docker | Docker Desktop 4.x | Latest stable |
| NVIDIA Driver | 535+ | 560+ |

### Software Stack
- **Docker Desktop** with WSL2 backend and GPU support enabled
- **Git for Windows** (provides `sh.exe` for Harbor CLI on Windows)
- **Harbor** — cloned from this repository

## Quick Start (5 commands)

```bash
# 1. Clone and enter
git clone <your-private-repo-url> harbor && cd harbor

# 2. Configure for TurboQuant
harbor config set llamacpp.extra_args "--cache-type-k turbo4 --cache-type-v turbo4 -c 131072 --n-gpu-layers 999 --flash-attn on --no-mmap --batch-size 256 --ubatch-size 256"

# 3. Download a model
curl.exe -L -o services/llamacpp/data/Qwen3.5-9B-Q5_K_M.gguf \
  "https://huggingface.co/bartowski/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q5_K_M.gguf"

# 4. Set the model and start
harbor llamacpp gguf /app/data/Qwen3.5-9B-Q5_K_M.gguf
harbor up llamacpp webui

# 5. Open the UI
# Navigate to http://localhost:33801
```

## Detailed Setup

### Step 1: Install Docker Desktop with GPU Support

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Enable WSL2 backend in Docker Desktop settings
3. Enable GPU support: **Settings > Resources > GPU** — toggle ON
4. Restart Docker Desktop

Verify GPU access:
```powershell
docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi
```

### Step 2: Clone Harbor

```powershell
git clone <your-repo-url> c:\Python_Projects\Harbor
cd c:\Python_Projects\Harbor
```

### Step 3: Build the Custom TurboQuant Image

The TurboQuant fork adds 4-bit KV cache compression, reducing VRAM consumption by ~4x for the KV cache. This enables 128k+ context windows on consumer GPUs.

```powershell
# Build the custom CUDA image from the TurboQuant fork
docker build `
  -t "ghcr.io/ggml-org/llama.cpp:server-cuda" `
  --target server `
  -f .devops/cuda.Dockerfile `
  "https://github.com/TheTom/llama-cpp-turboquant.git#feature/turboquant-kv-cache"
```

> [!NOTE]
> This build takes 15-30 minutes depending on your hardware. The resulting image replaces the default `server-cuda` tag so Harbor uses it automatically.

**Verify the build:**
```powershell
docker images "ghcr.io/ggml-org/llama.cpp:server-cuda"
```
Expected size: ~6 GB.

### Step 4: Download Model Weights

Download the GGUF model file into Harbor's llamacpp data directory:

```powershell
# Qwen 3.5 9B — Dense, Q5_K_M quantization (6.1 GB)
# Excellent daily driver, ~42 t/s on RTX 3070, ~80+ t/s expected on RTX 3090
curl.exe -L -o services/llamacpp/data/Qwen3.5-9B-Q5_K_M.gguf `
  "https://huggingface.co/bartowski/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q5_K_M.gguf"
```

#### Additional Models (RTX 3090 with 24 GB VRAM)

With 24 GB VRAM, you can run the 35B MoE model comfortably:

```powershell
# Qwen 3.6 35B-A3B — MoE, IQ4_XS quantization (~12 GB)
# Only 3B active parameters per token, so inference is fast despite 35B total
curl.exe -L -o services/llamacpp/data/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf `
  "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf"
```

### Step 5: Configure Harbor

```powershell
# On Windows, wrap harbor.sh with Git Bash:
$harbor = { & "C:\Program Files\Git\bin\sh.exe" harbor.sh @args }

# Set the model
& $harbor llamacpp gguf /app/data/Qwen3.5-9B-Q5_K_M.gguf

# Set TurboQuant runtime flags
& $harbor config set llamacpp.extra_args "--cache-type-k turbo4 --cache-type-v turbo4 -c 131072 --n-gpu-layers 999 --flash-attn on --no-mmap --batch-size 256 --ubatch-size 256"

# Propagate default.env changes
& $harbor config update
```

#### GPU-Specific Tuning

| GPU | Context (`-c`) | Compression | Expected Gen Speed |
|-----|----------------|-------------|-------------------|
| RTX 3070 (8 GB) | 131072 (128k) | `turbo4` | ~42 t/s (9B) |
| RTX 3090 (24 GB) | 131072 (128k) | `turbo4` | ~80+ t/s (9B), ~15-20 t/s (35B) |
| RTX 3090 (24 GB) | 262144 (256k) | `turbo4` | ~60+ t/s (9B) |
| RTX 4090 (24 GB) | 262144 (256k) | `turbo4` | ~120+ t/s (9B) |

For RTX 3090, you can also try higher quality compression:
```powershell
# turbo3 = 3-bit KV, slightly better quality, more VRAM
& $harbor config set llamacpp.extra_args "--cache-type-k turbo3 --cache-type-v turbo4 -c 262144 --n-gpu-layers 999 --flash-attn on --no-mmap --batch-size 512 --ubatch-size 512"
```

### Step 6: Start the Stack

```powershell
# Start llamacpp and Open WebUI
& $harbor up llamacpp webui

# Or using docker compose directly (if harbor CLI has pathing issues on Windows):
docker compose --env-file .env `
  -f compose.yml `
  -f services/compose.llamacpp.yml `
  -f services/compose.x.llamacpp.nvidia.yml `
  -f services/compose.webui.yml `
  up -d
```

### Step 7: Verify

```powershell
# Check containers are healthy
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check VRAM usage
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader

# Test inference
$body = @{ messages = @( @{ role = "user"; content = "What is 2+2?" } ); temperature = 0; max_tokens = 50 } | ConvertTo-Json -Depth 5
$r = Invoke-RestMethod -Uri "http://localhost:33831/v1/chat/completions" -Method Post -Body $body -ContentType "application/json"
"Response: $($r.choices[0].message.content) | Speed: $($r.timings.predicted_per_second) t/s"
```

### Step 8: Configure Open WebUI

1. Open `http://localhost:33801` in your browser
2. Create an admin account (local-only, any email/password)
3. Go to **Admin Panel > Settings > Connections**
4. Add an OpenAI-compatible connection:
   - **URL:** `http://harbor.llamacpp:8080/v1`
   - **API Key:** `sk-dummy` (any non-empty string)
5. The model list should auto-populate with `Qwen3.5-9B-Q5_K_M.gguf`
6. Start chatting

## Switching Models

To swap between the 9B and 35B models at runtime:

```powershell
# Switch to 35B MoE
& $harbor llamacpp gguf /app/data/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf
docker compose --env-file .env -f compose.yml -f services/compose.llamacpp.yml -f services/compose.x.llamacpp.nvidia.yml up -d llamacpp

# Switch back to 9B
& $harbor llamacpp gguf /app/data/Qwen3.5-9B-Q5_K_M.gguf
docker compose --env-file .env -f compose.yml -f services/compose.llamacpp.yml -f services/compose.x.llamacpp.nvidia.yml up -d llamacpp
```

> [!WARNING]
> On RTX 3070 (8 GB), the 35B model exceeds physical VRAM and relies on CUDA virtual memory overcommit. Load times are 5+ minutes and inference is unreliable. The 35B runs comfortably on 24 GB cards (RTX 3090/4090).

## Golden Configuration Reference

These are the exact `.env` values from the validated RTX 3070 deployment:

```ini
# Core
HARBOR_LLAMACPP_HOST_PORT=33831
HARBOR_LLAMACPP_GGUF="/app/data/Qwen3.5-9B-Q5_K_M.gguf"
HARBOR_LLAMACPP_MODEL_SPECIFIER="-m /app/data/Qwen3.5-9B-Q5_K_M.gguf"
HARBOR_LLAMACPP_EXTRA_ARGS="--cache-type-k turbo4 --cache-type-v turbo4 -c 131072 --n-gpu-layers 999 --flash-attn on --no-mmap --batch-size 256 --ubatch-size 256"

# Build (only needed if rebuilding the image)
HARBOR_LLAMACPP_BUILD_REF="feature/turboquant-kv-cache"
HARBOR_LLAMACPP_BUILD_REPO="https://github.com/TheTom/llama-cpp-turboquant.git"
HARBOR_LLAMACPP_BUILD_CUDA_ARCH=default

# WebUI
HARBOR_WEBUI_HOST_PORT=33801
HARBOR_WEBUI_SECRET="h@rb0r"
HARBOR_WEBUI_NAME="Harbor"
```

## Validated Performance (RTX 3070, 8 GB)

| Metric | Value |
|--------|-------|
| Model | Qwen 3.5 9B, Q5_K_M |
| Generation Speed | 33-54 t/s (avg ~42) |
| Prompt Processing | 19-232 t/s (cache-dependent) |
| Context Window | 128k tokens |
| VRAM Usage | ~7.8 / 8.2 GB |
| KV Cache (turbo4) | ~1 GB for 128k ctx |
| TurboQuant Active | Yes (rotation matrices 128x128) |

## Troubleshooting

### `--flash-attn` errors
Use `--flash-attn on` explicitly, not `auto`. The TurboQuant fork requires the explicit value.

### Harbor CLI path errors on Windows
Harbor's Deno-based tools can mangle Windows paths. Use direct `docker compose` commands as shown in Step 6 as a workaround.

### Model loading takes forever
The 35B model with VRAM overcommit can take 5+ minutes. For 8 GB cards, stick with the 9B model. On 24 GB cards, the 35B should load in under 60 seconds.

### WebUI shows no models
Ensure the OpenAI connection URL is `http://harbor.llamacpp:8080/v1` (using the Docker internal hostname, not `localhost`).

### GGUF download fails with 401
Some HuggingFace repos require authentication. Use `curl.exe` with a token:
```powershell
curl.exe -L -H "Authorization: Bearer hf_YOUR_TOKEN" -o services/llamacpp/data/model.gguf "https://huggingface.co/..."
```
