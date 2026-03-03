# Runpod Installation Scripts

Qwen2.5-72B-Instruct-Q4_K_M running with llama.cpp

```bash
curl -fsSL https://raw.githubusercontent.com/sulla-ai/runpod-installation-scripts/main/Qwen2.5-72B-Instruct-Q4_K_M | bash
```

Local repo usage:

```bash
bash install.sh
```

After launch:

```bash
tail -f /tmp/vllm.log
curl http://127.0.0.1:8000/v1/models
```
