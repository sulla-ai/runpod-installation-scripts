#!/usr/bin/env bash
set -euo pipefail

# 1) Clean and install compatible vLLM stack
python3 -m pip install -U pip setuptools wheel
python3 -m pip uninstall -y torch torchvision torchaudio vllm flash-attn flashinfer-python hf_transfer huggingface_hub transformers || true
python3 -m pip install --pre "vllm[flashinfer]" \
  --extra-index-url https://wheels.vllm.ai/nightly \
  --extra-index-url https://download.pytorch.org/whl/cu128

# 2) Pin HF libs to compatible range
python3 -m pip install --no-cache-dir "huggingface_hub>=0.36,<1.0" "transformers==4.57.6"

# 3) Avoid hf_transfer env trap
unset HF_HUB_ENABLE_HF_TRANSFER

nohup python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen3.5-72B-Instruct-AWQ \
  --host 0.0.0.0 \
  --port 8000 \
  --gpu-memory-utilization 0.88 \
  --max-model-len 32768 \
  --kv-cache-dtype fp8 \
  --enable-prefix-caching \
  --tensor-parallel-size 1 \
  2>&1 | tee /tmp/vllm.log

echo "vLLM started in background."
echo "Logs: tail -f /tmp/vllm.log"
echo "Health check: curl http://127.0.0.1:8000/v1/models"
