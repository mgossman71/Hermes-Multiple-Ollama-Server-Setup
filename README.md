# Hermes Multiple Ollama Server Setup

Complete guide for configuring Hermes Agent to connect to multiple Ollama servers with Telegram model switching support.

## Overview

This setup enables a single Hermes Agent instance to:
- Connect to multiple Ollama servers (local network, cloud, secondary instances)
- Switch between models dynamically via Telegram `/model` command
- Maintain provider configurations with proper model context limits
- Failover between servers for high availability

## Prerequisites

- Hermes Agent installed and configured
- Access to one or more Ollama servers (local or remote)
- GitHub CLI (`gh`) for repository management (optional, for sharing your config)
- Telegram bot configured for your Hermes instance

## Architecture

```
┌─────────────────┐
│  Hermes Agent   │
│   (Telegram)    │
└────────┬────────┘
         │
         │ /model command
         ▼
┌─────────────────────────────────────────┐
│         config.yaml (Providers)         │
├─────────────────────────────────────────┤
│  • ollama-cloud (default)               │
│  • ollama-local (LAN)                   │
│  • ollama-secondary (backup)            │
└─────────────────────────────────────────┘
         │
         ├──────────────┬──────────────┐
         ▼              ▼              ▼
   ┌──────────┐  ┌──────────┐  ┌──────────┐
   │  https:  │  │  http:   │  │  http:   │
   │ollama.com│  │10.0.0.86 │  │10.0.0.140│
   │ :8080    │  │ :11434   │  │ :11434   │
   └──────────┘  └──────────┘  └──────────┘
```

## Step 1: Discover Your Ollama Servers

Before configuring, identify all available Ollama servers:

### Check Local Network for Ollama Instances

```bash
# Scan common Ollama ports on your network
nmap -p 11434 10.0.0.0/24

# Or test specific IPs
curl http://10.0.0.86:11434/api/tags | jq
```

### List Available Models on Each Server

```bash
# For each server, list models
curl http://<SERVER_IP>:11434/api/tags | jq '.models[].name'
```

### Note Model Context Windows

Different models have different context limits. Document these:

```bash
# Get model details
curl http://<SERVER_IP>:11434/api/show -d '{"name": "qwen2.5:7b"}' | jq '.details'
```

## Step 2: Configure Hermes Providers

Edit your Hermes configuration file at `~/.hermes/config.yaml`:

### Provider Configuration Structure

```yaml
providers:
  # Primary cloud provider (default)
  ollama-cloud:
    base_url: https://ollama.com/v1
    models:
      - name: qwen3.5:397b
        context_window: 256000
        is_default: true

  # Local network Ollama server
  ollama-local:
    base_url: http://10.0.0.86:11434/v1
    models:
      - name: qwen2.5:7b
        context_window: 64000
      - name: gemma4:31b-cloud
        context_window: 128000
      - name: qwen3.5:397b-cloud
        context_window: 256000

  # Secondary backup server
  ollama-secondary:
    base_url: http://10.0.0.140:11434/v1
    models:
      - name: qwen3:32b
        context_window: 128000
      - name: qwen3.5:35b
        context_window: 256000
      - name: qwen2.5-coder:32b
        context_window: 128000
      - name: deepseek-r1:32b
        context_window: 128000
      - name: qwen2.5vl:32b
        context_window: 64000
```

### Key Configuration Fields

| Field | Description | Required |
|-------|-------------|----------|
| `base_url` | Ollama server endpoint (add `/v1` for OpenAI compat) | Yes |
| `name` | Model identifier as it appears on the server | Yes |
| `context_window` | Maximum tokens the model supports | Yes |
| `is_default` | Marks which model loads by default | Optional (one per provider) |

## Step 3: Enable Telegram Model Switching

Hermes supports dynamic model switching via Telegram commands. This is handled automatically once providers are configured.

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `/model` | List all available models | `/model` |
| `/model <name>` | Switch to specific model | `/model qwen2.5:7b` |
| `/model <provider>/<name>` | Switch with provider prefix | `/model ollama-local/qwen2.5:7b` |

### How It Works

1. User sends `/model` in Telegram
2. Hermes displays all available models across all providers
3. User selects a model by name or number
4. Hermes updates the active provider/model for that chat session
5. All subsequent messages use the selected model

### Model Selection Interface

When you run `/model`, you'll see output like:

```
Available Models:
─────────────────
[1] ollama-cloud/qwen3.5:397b (default) [256k ctx]
[2] ollama-local/qwen2.5:7b [64k ctx]
[3] ollama-local/gemma4:31b-cloud [128k ctx]
[4] ollama-local/qwen3.5:397b-cloud [256k ctx]
[5] ollama-secondary/qwen3:32b [128k ctx]
[6] ollama-secondary/qwen3.5:35b [256k ctx]
[7] ollama-secondary/qwen2.5-coder:32b [128k ctx]
[8] ollama-secondary/deepseek-r1:32b [128k ctx]
[9] ollama-secondary/qwen2.5vl:32b [64k ctx]

Current: ollama-cloud/qwen3.5:397b

Reply with the number or model name to switch.
```

## Step 4: Verify Configuration

### Test Provider Connectivity

```bash
# Test each provider endpoint
curl http://10.0.0.86:11434/api/tags
curl http://10.0.0.140:11434/api/tags
curl https://ollama.com/v1/models
```

### Restart Hermes Agent

```bash
# If running as a service
systemctl restart hermes-agent

# Or restart manually
pkill hermes-agent
hermes-agent start
```

### Test Model Switching in Telegram

1. Open your Telegram bot chat
2. Send `/model` to see available models
3. Select a model from a different provider
4. Send a test message to verify it works

## Step 5: Troubleshooting

### Common Issues

#### "Provider not found" Error

**Cause:** Typo in provider name or config not reloaded

**Fix:**
```bash
# Check config syntax
hermes config validate

# Restart Hermes
systemctl restart hermes-agent
```

#### "Model not available" Error

**Cause:** Model doesn't exist on the specified server

**Fix:**
```bash
# List models on the server
curl http://<SERVER_IP>:11434/api/tags | jq

# Pull the model if needed
ollama pull <model-name>
```

#### Telegram `/model` Command Not Responding

**Cause:** Gateway disconnected or command not registered

**Fix:**
```bash
# Check gateway status
hermes gateway status

# Restart gateway
hermes gateway restart
```

#### Slow Response Times

**Cause:** Network latency to remote Ollama server

**Fix:**
- Use local network servers when possible
- Set appropriate timeouts in config
- Consider running Ollama on the same machine as Hermes

### Debug Commands

```bash
# Check active provider
hermes config get providers

# View current model
hermes config get current_model

# Test Ollama connectivity
ollama list

# Check Hermes logs
journalctl -u hermes-agent -f
```

## Step 6: Advanced Configuration

### Load Balancing with Failover

For high availability, configure providers with automatic failover:

```yaml
providers:
  ollama-primary:
    base_url: http://10.0.0.86:11434/v1
    models:
      - name: qwen2.5:7b
        context_window: 64000
    failover:
      - ollama-backup

  ollama-backup:
    base_url: http://10.0.0.140:11434/v1
    models:
      - name: qwen2.5:7b
        context_window: 64000
```

### Provider-Specific Settings

Some providers may need additional configuration:

```yaml
providers:
  ollama-local:
    base_url: http://10.0.0.86:11434/v1
    timeout: 120  # Request timeout in seconds
    retry_count: 3
    models:
      - name: qwen2.5:7b
        context_window: 64000
        temperature: 0.7  # Default temperature
```

### Memory Management

For servers with limited VRAM, configure model unloading:

```yaml
providers:
  ollama-local:
    base_url: http://10.0.0.86:11434/v1
    keep_alive: 5m  # Keep model loaded for 5 minutes
    models:
      - name: qwen2.5:7b
        context_window: 64000
```

## Quick Start Script

Use this script to auto-detect Ollama servers on your network:

```bash
#!/bin/bash
# detect-ollama.sh

echo "Scanning for Ollama servers on 10.0.0.0/24..."

for i in {1..254}; do
    ip="10.0.0.$i"
    if curl -s --connect-timeout 1 http://$ip:11434/api/tags > /dev/null 2>&1; then
        echo "✓ Found Ollama at $ip:11434"
        echo "  Models:"
        curl -s http://$ip:11434/api/tags | jq -r '.models[].name' | sed 's/^/    /'
    fi
done
```

## Sharing Your Configuration

To share your multi-Ollama setup with others:

### Option 1: GitHub Repository

```bash
# Create a new repo
gh repo create hermes-ollama-config --public

# Add your config
cp ~/.hermes/config.yaml ./config.example.yaml

# Commit and push
git add .
git commit -m "Add multi-Ollama configuration example"
git push -u origin main
```

### Option 2: Direct Config Export

```bash
# Export your provider config (sanitize sensitive data first)
hermes config get providers > my-ollama-providers.yaml
```

## Best Practices

1. **Name providers descriptively**: Use `ollama-local`, `ollama-cloud`, `ollama-secondary` instead of `provider1`, `provider2`

2. **Document context windows**: Always specify `context_window` for each model to prevent token errors

3. **Test failover**: Regularly verify backup servers are accessible

4. **Monitor performance**: Track response times per provider to identify bottlenecks

5. **Keep configs versioned**: Use Git to track changes to your Hermes configuration

6. **Use Telegram commands**: Leverage `/model` for quick switching instead of editing config files

## Additional Resources

- [Hermes Agent Documentation](https://hermes-agent.nousresearch.com/docs)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Hermes Skills Repository](https://github.com/NousResearch/hermes-agent/tree/main/skills)

## License

This documentation is provided as-is for the Hermes Agent community.

---

**Contributors:** Mark Gossman (@mgossman71)  
**Last Updated:** 2026-05-13  
**Compatible With:** Hermes Agent v2.0+
