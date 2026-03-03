#!/bin/bash
# =============================================================================
# Qwen2.5-72B-Instruct-Q6_K + llama.cpp Server Setup
# =============================================================================
#
# Model:          Qwen2.5-72B-Instruct-Q6_K.gguf
# Quantization:   6-bit K-quant (higher quality than Q4, best single-GPU choice)
# Backend:        llama.cpp (stable single-GPU inference, OpenAI-compatible API)
# @see: https://huggingface.co/bartowski/Qwen2.5-72B-Instruct-GGUF
#
# Target Hardware:
#   NVIDIA RTX Pro 6000 (96 GB VRAM) — Single GPU
#
# Resource Requirements & Fit:
#   - Disk Space:     ~66 GB (model file) + ~5–8 GB overhead = ~75 GB recommended
#   - VRAM Usage:     ~73–78 GB (full offload + 32k context) → may spike during startup
#   - Safe VRAM Usage: ~68–72 GB when starting with 16k context (recommended default)
#   - Free VRAM:      ~24–28 GB remaining (good headroom for agents)
#
# Expected Capacity:
#   - 250 – 400+ concurrent OpenClaw / Sulla agents
#   - Excellent reasoning and tool-use performance
#   - Monthly cost on current RunPod: ~$490–$550
#
# What this script does:
#   1. Installs dependencies and builds latest llama.cpp with CUDA
#   2. Downloads the Qwen2.5-72B Q6_K model
#   3. Launches the server as a persistent daemon on port 8000
#      (starts with 16k context to survive the loading spike)
#
# Endpoint for all agents:
#   https://YOUR-POD-ID-8000.proxy.runpod.net/v1
#
# Created for: RunPod RTX Pro 6000 deployment
# Last Updated: March 2026
# =============================================================================

set -e
echo "=== Starting full setup for Qwen2.5-72B-Instruct-Q6_K.gguf ==="

# 1. Install dependencies
apt-get update -qq
apt-get install -y git cmake build-essential python3 python3-pip curl

# 2. Clone llama.cpp (if not already there)
if [ ! -d "/workspace/llama.cpp" ]; then
  echo "Cloning llama.cpp..."
  git clone https://github.com/ggerganov/llama.cpp /workspace/llama.cpp
fi

cd /workspace/llama.cpp

# 3. Build llama.cpp with CUDA
echo "Building llama.cpp with CUDA..."
rm -rf build
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release -j

# 4. Create models folder and download the exact model
mkdir -p /workspace/models
cd /workspace/models

if [ ! -f "Qwen2.5-72B-Instruct-Q6_K.gguf" ]; then
  echo "Downloading Qwen2.5-72B-Instruct-Q6_K.gguf (~66 GB)..."
  huggingface-cli download bartowski/Qwen2.5-72B-Instruct-GGUF Qwen2.5-72B-Instruct-Q6_K.gguf --local-dir .
fi

# 5. Start the server as daemon (16k context to survive startup spike)
echo "Starting llama-server..."
pkill -f llama-server || true
sleep 2

nohup /workspace/llama.cpp/build/bin/llama-server \
  -m /workspace/models/Qwen2.5-72B-Instruct-Q6_K.gguf \
  -c 16384 \                    # Safe starting context (can increase later if stable)
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
echo 'curl -k https://4l4uga9zmb46l3-8000.proxy.runpod.net/v1/chat/completions -H "Content-Type: application/json" -d '\''{"model":"Qwen2.5-72B-Instruct-Q6_K","messages":[{"role":"user","content":"Say hello from Sulla!"}],"max_tokens":30}'\'''
echo ""
echo "Check logs anytime with: tail -f /tmp/llama.log"
echo "Note: If you want 32k context later, stop the server and change -c to 32768 (may require restart if it OOMs)."
