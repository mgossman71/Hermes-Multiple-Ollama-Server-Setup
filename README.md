# Hermes Multiple Ollama Server Setup

Minimal guide for adding additional Ollama servers to Hermes Agent.

## Quick Start

### 1. Find Your Ollama Server

Scan your network or test a specific IP:

```bash
# Test a specific server
curl http://10.0.0.140:11434/api/tags | jq '.models[].name'
```

### 2. Edit Config

Open `~/.hermes/config.yaml` and add a new provider:

```yaml
providers:
  # Your existing provider(s)
  ollama-cloud:
    base_url: https://ollama.com/v1
    models:
    - name: qwen3.5:397b
      context_window: 256000
      is_default: true

  # Add your new server here
  ollama-140:
    base_url: http://10.0.0.140:11434/v1
    models:
    - name: qwen3.5:35b
      context_window: 256000
```

**Required fields:**
- `base_url` — Ollama server URL (must end with `/v1`)
- `name` — Model name as it appears on the server
- `context_window` — Max tokens the model supports

### 3. Restart Gateway

```bash
sudo systemctl restart hermes-gateway
```

### 4. Switch Models (Telegram)

In your Telegram chat:
- `/model` — List all available models
- `/model ollama-140/qwen3.5:35b` — Switch to specific model

## Common Context Windows

| Model | Context Window |
|-------|---------------|
| qwen2.5:7b | 64,000 |
| qwen3:32b | 128,000 |
| qwen3.5:35b | 256,000 |
| qwen3.5:397b | 256,000 |
| gemma3:27b | 128,000 |
| gemma4:31b | 128,000 |
| deepseek-r1:32b | 128,000 |

## Troubleshooting

**`/model` shows models but selection does nothing**
→ Gateway isn't running: `sudo systemctl restart hermes-gateway`

**"Provider not found"**
→ Typo in provider name or config not reloaded (restart gateway)

**"Model not available"**
→ Model doesn't exist on that server. Verify with `curl http://IP:11434/api/tags`

---

**Last Updated:** 2026-05-16  
**Compatible:** Hermes Agent v2.0+
