#!/bin/bash
# =============================================================================
# Qwen3.5-35B-A3B + llama.cpp Server Setup (Idempotent)
# =============================================================================
#
# Model:          Qwen3.5-35B-A3B (MoE — only ~3B active params)
# Quantization:   Q5_K_M (best quality that reliably fits)
# Backend:        llama.cpp (stable, no vLLM headaches)
#
# Target Hardware:
#   NVIDIA RTX Pro 6000 (96 GB VRAM) — Single GPU
#
# Resource Requirements & Fit:
#   - Disk Space:     ~42 GB (model file) + ~5 GB overhead = ~50 GB total
#   - VRAM Usage:     ~58–64 GB (full offload + 32k context)
#   - Free VRAM:      ~32–38 GB remaining (excellent headroom)
#   - VRAM Utilization: ~62% (very safe)
#
# Expected Capacity:
#   - 250 – 450+ concurrent OpenClaw / Sulla agents
#   - Strong Claude-like reasoning and tool use
#   - Monthly cost on current RunPod: ~$490–$550
#
# What this script does (idempotent — safe to rerun):
#   1. Installs dependencies only if needed
#   2. Clones/builds llama.cpp only if missing
#   3. Downloads Qwen3.5-35B-A3B-Q5_K_M.gguf only if missing
#   4. Launches the server as a persistent daemon on port 8000
#
# Endpoint for all agents:
#   https://4l4uga9zmb46l3-8000.proxy.runpod.net/v1
#
# Created for: RunPod RTX Pro 6000 deployment
# Last Updated: March 2026
# =============================================================================

set -e
echo "=== Starting idempotent setup for Qwen3.5-35B-A3B ==="

# 1. Install dependencies
apt-get update -qq
apt-get install -y git cmake build-essential python3 python3-pip curl

# 2. Clone llama.cpp only if missing
if [ ! -d "/workspace/llama.cpp" ]; then
  echo "Cloning llama.cpp..."
  git clone https://github.com/ggerganov/llama.cpp /workspace/llama.cpp
fi

cd /workspace/llama.cpp

# 3. Build only if binary is missing
if [ ! -f "build/bin/llama-server" ]; then
  echo "Building llama.cpp with CUDA..."
  rm -rf build
  cmake -B build -DGGML_CUDA=ON
  cmake --build build --config Release -j
fi

# 4. Create models folder and download the exact model (only if missing)
mkdir -p /workspace/models
cd /workspace/models

if [ ! -f "Qwen3.5-35B-A3B-Q5_K_M.gguf" ]; then
  echo "Downloading Qwen3.5-35B-A3B-Q5_K_M.gguf (~42 GB)..."
  huggingface-cli download bartowski/Qwen_Qwen3.5-35B-A3B-GGUF Qwen3.5-35B-A3B-Q5_K_M.gguf --local-dir .
fi

# 5. Start the server as daemon
echo "Starting llama-server..."
pkill -f llama-server || true
sleep 2

nohup /workspace/llama.cpp/build/bin/llama-server \
  -m /workspace/models/Qwen3.5-35B-A3B-Q5_K_M.gguf \
  -c 32768 \
  --host 0.0.0.0 \
  --port 8000 \
  -ngl 99 \
  > /tmp/llama.log 2>&1 &

echo "=== Setup complete! ==="
echo ""
echo "Your API endpoint is:"
echo "https://4l4uga9zmb46l3-8000.proxy.runpod.net/v1"
echo ""
echo "Test it now with:"
echo 'curl -k https://4l4uga9zmb46l3-8000.proxy.runpod.net/v1/chat/completions -H "Content-Type: application/json" -d '\''{"model":"Qwen3.5-35B-A3B-Q5_K_M","messages":[{"role":"user","content":"Say hello from Sulla!"}],"max_tokens":30}'\'''
echo ""
echo "Check logs anytime with: tail -f /tmp/llama.log"
