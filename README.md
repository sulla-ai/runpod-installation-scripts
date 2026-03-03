# Runpod Installation Scripts

Qwen2.5-72B-Instruct-Q4_K_M running with llama.cpp

```bash
curl -fsSL https://raw.githubusercontent.com/sulla-ai/runpod-installation-scripts/main/install-llama-cpp-Qwen2.5-72B-Instruct-Q4_K_M.sh | bash
```

Qwen2.5-72B-Instruct-Q6_K running with llama.cpp

```bash
curl -fsSL https://raw.githubusercontent.com/sulla-ai/runpod-installation-scripts/main/install-llama-cpp-Qwen2.5-72B-Instruct-Q6_K.sh | bash
```







After launch:

```bash
tail -f /tmp/vllm.log
curl http://127.0.0.1:8000/v1/models
```
