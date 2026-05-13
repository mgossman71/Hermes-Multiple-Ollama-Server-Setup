# Quick Reference: Multiple Ollama Setup

## One-Liner Commands

### Check Current Configuration
```bash
hermes config get providers
```

### Test Ollama Server Connectivity
```bash
curl http://<IP>:11434/api/tags | jq
```

### Restart Hermes Agent
```bash
systemctl restart hermes-agent
# OR
pkill hermes-agent && hermes-agent start
```

### View Hermes Logs
```bash
journalctl -u hermes-agent -f --no-pager
```

## Telegram Commands

| Command | Description |
|---------|-------------|
| `/model` | List all available models |
| `/model <name>` | Switch to specific model |
| `/start` | Reset bot to default |
| `/help` | Show all commands |

## Configuration Quick Edit

### Add a New Provider
```yaml
providers:
  ollama-new:
    base_url: http://<IP>:11434/v1
    timeout: 60
    models:
      - name: <model-name>
        context_window: <tokens>
```

### Change Default Model
```yaml
defaults:
  provider: ollama-local
  model: qwen2.5:7b
```

### Enable Model Switching
```yaml
telegram:
  model_switching: true
```

## Troubleshooting Flow

```
Problem: Model not responding
  ├─ Check server: curl http://<IP>:11434/api/tags
  ├─ Check config: hermes config validate
  └─ Restart: systemctl restart hermes-agent

Problem: /model command not working
  ├─ Check Telegram: telegram.enabled = true
  ├─ Check switching: telegram.model_switching = true
  └─ Check gateway: hermes gateway status

Problem: Slow responses
  ├─ Test latency: ping <IP>
  ├─ Check timeout: Increase provider.timeout
  └─ Use local: Switch to ollama-local provider
```

## Network Scan (Quick)
```bash
# Scan for Ollama on common ports
for i in {1..50}; do
  curl -s --connect-timeout 1 http://10.0.0.$i:11434/api/tags > /dev/null 2>&1 && \
  echo "Found: 10.0.0.$i"
done
```

## Model Context Windows (Common Models)

| Model | Context Window |
|-------|---------------|
| qwen2.5:7b | 64,000 |
| qwen3:32b | 128,000 |
| qwen3.5:35b | 256,000 |
| gemma4:31b | 128,000 |
| deepseek-r1:32b | 128,000 |
| llama3:70b | 128,000 |
| mistral:7b | 32,000 |

## Backup & Restore

### Backup Config
```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.backup.$(date +%Y%m%d)
```

### Restore Config
```bash
cp ~/.hermes/config.yaml.backup.YYYYMMDD ~/.hermes/config.yaml
systemctl restart hermes-agent
```

## Performance Tips

1. **Use local servers** for faster response times
2. **Set keep_alive** to prevent model unloading: `keep_alive: 10m`
3. **Increase timeout** for large models: `timeout: 120`
4. **Enable retries** for reliability: `retry_count: 3`
5. **Monitor VRAM** on local servers with `nvidia-smi`

## Security Notes

- 🔒 Use HTTPS for cloud providers
- 🔒 Firewall local Ollama ports (11434) to trusted IPs only
- 🔒 Don't commit config.yaml with sensitive data to Git
- 🔒 Use separate API keys for different services

---

**Full Documentation:** See [README.md](README.md)  
**Example Config:** See [config.example.yaml](config.example.yaml)
