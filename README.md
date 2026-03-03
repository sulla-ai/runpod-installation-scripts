# vllm-5090-DeepSeek-R1-Distill-Qwen-7B

One-line remote install + launch (run on your RunPod shell):

```bash
curl -fsSL https://raw.githubusercontent.com/sulla-ai/custom-gpu-server-config/main/install.sh | bash
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