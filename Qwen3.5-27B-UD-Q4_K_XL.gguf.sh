#!/bin/bash
# NOTE: When creating the RunPod pod, expose port 8000 as HTTP in the pod template.
set -e

MODEL_DIR="/workspace/models"
MODEL_FILE="Qwen3.5-27B-UD-Q4_K_XL.gguf"
MODEL_URL="https://huggingface.co/unsloth/Qwen3.5-27B-GGUF/resolve/main/${MODEL_FILE}"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"
LLAMA_DIR="/workspace/llama.cpp"
PORT=8000
CONTEXT_SIZE=32768
GPU_LAYERS=99
PARALLEL=1

echo "============================================="
echo " llama.cpp + Qwen3.5-27B Setup (5090)"
echo "============================================="

# --- Install build dependencies ---
echo "[1/4] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq build-essential cmake git wget curl aria2 > /dev/null 2>&1
echo "       Done."

# --- Clone and build llama.cpp ---
echo "[2/4] Building llama.cpp from source with CUDA..."
if [ -d "$LLAMA_DIR" ]; then
    echo "       Removing old llama.cpp directory..."
    rm -rf "$LLAMA_DIR"
fi
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
cd "$LLAMA_DIR"
mkdir -p build && cd build
cmake .. -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_CUDA_ARCHITECTURES=native > /dev/null 2>&1
make -j"$(nproc)" llama-server 2>&1 | tail -5
echo "       Build complete."

# Verify binary
"${LLAMA_DIR}/build/bin/llama-server" --version

# --- Download model ---
echo "[3/4] Downloading model (skips if already present)..."
mkdir -p "$MODEL_DIR"
if [ -f "$MODEL_PATH" ]; then
    echo "       Model already exists at ${MODEL_PATH}, skipping download."
else
    echo "       Downloading ${MODEL_FILE} with aria2c (16 connections)..."
    aria2c -x 16 -s 16 --max-connection-per-server=16 \
        --min-split-size=1M --file-allocation=none \
        -d "$MODEL_DIR" -o "$MODEL_FILE" "$MODEL_URL"
    echo "       Download complete."
fi

# --- Launch server ---
echo "[4/4] Starting llama-server on port ${PORT}..."
echo ""
echo "  Model:    ${MODEL_FILE}"
echo "  Context:  ${CONTEXT_SIZE} tokens"
echo "  KV cache: q8_0 (keys + values)"
echo "  Port:     ${PORT}"
echo "  GPU:      all layers offloaded"
echo "  no-mmap:  on (required for RunPod network filesystem)"
echo ""

# Kill any existing server
pkill -f llama-server || true
sleep 2

nohup "${LLAMA_DIR}/build/bin/llama-server" \
    --model "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --ctx-size "$CONTEXT_SIZE" \
    --n-gpu-layers "$GPU_LAYERS" \
    --cache-type-k q8_0 \
    --cache-type-v q8_0 \
    -np "$PARALLEL" \
    --flash-attn \
    --no-mmap \
    > /tmp/llama.log 2>&1 &

echo "Server started in background. Logs: /tmp/llama.log"
echo "Waiting for server to initialize..."
sleep 10
if curl -s http://localhost:${PORT}/health | grep -q "ok"; then
    echo "Server is healthy and ready!"
else
    echo "Server may still be loading. Check logs: tail -f /tmp/llama.log"
fi

# Keep container alive
tail -f /tmp/llama.log
