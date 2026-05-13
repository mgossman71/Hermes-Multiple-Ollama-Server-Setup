#!/bin/bash
# setup-ollama-providers.sh
# Automated setup script for configuring multiple Ollama providers in Hermes Agent

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Hermes Multiple Ollama Server Setup                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Hermes is installed
if ! command -v hermes &> /dev/null; then
    echo -e "${RED}Error: Hermes Agent is not installed or not in PATH${NC}"
    echo "Please install Hermes Agent first: https://hermes-agent.nousresearch.com/docs"
    exit 1
fi

echo -e "${GREEN}✓ Hermes Agent detected${NC}"

# Check if config exists
CONFIG_FILE="$HOME/.hermes/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}! Config file not found at $CONFIG_FILE${NC}"
    echo "  Creating default config..."
    mkdir -p "$HOME/.hermes"
    touch "$CONFIG_FILE"
fi

# Function to scan network for Ollama servers
scan_network() {
    echo
    echo "Scanning network for Ollama servers..."
    echo "This may take up to 30 seconds..."
    echo
    
    local servers=()
    
    # Common local network ranges
    for prefix in "10.0.0" "192.168.1" "192.168.0" "172.16.0"; do
        for i in {1..50}; do
            ip="$prefix.$i"
            if curl -s --connect-timeout 1 "http://$ip:11434/api/tags" > /dev/null 2>&1; then
                echo -e "  ${GREEN}✓ Found Ollama at $ip:11434${NC}"
                servers+=("$ip")
            fi
        done
    done
    
    if [ ${#servers[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}No Ollama servers found on common network ranges${NC}"
    else
        echo
        echo -e "${GREEN}Discovered ${#servers[@]} Ollama server(s):${NC}"
        for server in "${servers[@]}"; do
            echo "  - http://$server:11434"
        done
    fi
    
    echo "${servers[@]}"
}

# Function to list models on a server
list_models() {
    local server_url="$1"
    echo
    echo "Models available on $server_url:"
    curl -s "$server_url/api/tags" | jq -r '.models[] | "  • \(.name) (\(.details.parameter_size // "unknown"))"' 2>/dev/null || echo "  Unable to fetch models"
}

# Function to backup existing config
backup_config() {
    if [ -f "$CONFIG_FILE" ]; then
        local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        echo -e "${GREEN}✓ Backed up existing config to $backup_file${NC}"
    fi
}

# Function to generate provider config
generate_provider_config() {
    local provider_name="$1"
    local base_url="$2"
    local is_default="$3"
    
    echo "  $provider_name:"
    echo "    base_url: $base_url"
    echo "    timeout: 60"
    echo "    retry_count: 2"
    if [ "$is_default" = "true" ]; then
        echo "    models:"
        echo "      - name: qwen2.5:7b"
        echo "        context_window: 64000"
        echo "        is_default: true"
    else
        echo "    models:"
        echo "      - name: qwen2.5:7b"
        echo "        context_window: 64000"
    fi
}

# Main setup flow
echo "This script will help you configure multiple Ollama providers for Hermes Agent."
echo
read -p "Do you want to scan your network for Ollama servers? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SCAN_RESULTS=$(scan_network)
fi

echo
echo "═══════════════════════════════════════════════════════════"
echo "Configuration Options"
echo "═══════════════════════════════════════════════════════════"
echo
echo "You can configure the following providers:"
echo "  1. ollama-cloud (https://ollama.com/v1) - Ollama's cloud service"
echo "  2. ollama-local (your LAN server) - Fast local inference"
echo "  3. ollama-secondary (backup server) - High availability"
echo

read -p "Enable ollama-cloud provider? (y/n) " -n 1 -r
echo
ENABLE_CLOUD=$REPLY

read -p "Enable ollama-local provider? (y/n) " -n 1 -r
echo
ENABLE_LOCAL=$REPLY

if [[ $ENABLE_LOCAL =~ ^[Yy]$ ]]; then
    read -p "Enter local Ollama server IP (or press Enter for 10.0.0.86): " LOCAL_IP
    LOCAL_IP=${LOCAL_IP:-"10.0.0.86"}
fi

read -p "Enable ollama-secondary provider? (y/n) " -n 1 -r
echo
ENABLE_SECONDARY=$REPLY

if [[ $ENABLE_SECONDARY =~ ^[Yy]$ ]]; then
    read -p "Enter secondary Ollama server IP (or press Enter for 10.0.0.140): " SECONDARY_IP
    SECONDARY_IP=${SECONDARY_IP:-"10.0.0.140"}
fi

echo
echo "Generating configuration..."
echo

# Backup existing config
backup_config

# Create new config
cat > "$CONFIG_FILE" << EOF
# Hermes Agent Configuration - Multiple Ollama Providers
# Generated: $(date)
# 
# This configuration enables multiple Ollama servers with Telegram model switching.
# Use /model in Telegram to switch between providers and models.

providers:
EOF

# Add cloud provider if enabled
if [[ $ENABLE_CLOUD =~ ^[Yy]$ ]]; then
    cat >> "$CONFIG_FILE" << 'EOF'
  # Primary cloud provider
  ollama-cloud:
    base_url: https://ollama.com/v1
    timeout: 120
    retry_count: 3
    models:
      - name: qwen3.5:397b
        context_window: 256000
        is_default: true
        description: "Primary large model for complex tasks"

EOF
    echo -e "${GREEN}✓ Added ollama-cloud provider${NC}"
fi

# Add local provider if enabled
if [[ $ENABLE_LOCAL =~ ^[Yy]$ ]]; then
    cat >> "$CONFIG_FILE" << EOF
  # Local network provider
  ollama-local:
    base_url: http://$LOCAL_IP:11434/v1
    timeout: 60
    retry_count: 2
    keep_alive: 10m
    models:
      - name: qwen2.5:7b
        context_window: 64000
        description: "Fast local model for quick tasks"

EOF
    echo -e "${GREEN}✓ Added ollama-local provider ($LOCAL_IP)${NC}"
fi

# Add secondary provider if enabled
if [[ $ENABLE_SECONDARY =~ ^[Yy]$ ]]; then
    cat >> "$CONFIG_FILE" << EOF
  # Secondary backup provider
  ollama-secondary:
    base_url: http://$SECONDARY_IP:11434/v1
    timeout: 60
    retry_count: 2
    models:
      - name: qwen3:32b
        context_window: 128000
        description: "Backup server for high availability"

EOF
    echo -e "${GREEN}✓ Added ollama-secondary provider ($SECONDARY_IP)${NC}"
fi

# Add Telegram and defaults configuration
cat >> "$CONFIG_FILE" << 'EOF'
# Telegram configuration
telegram:
  enabled: true
  model_switching: true
  show_context_window: true

# Default behavior
defaults:
  provider: ollama-cloud
  model: qwen3.5:397b
  temperature: 0.7
  max_tokens: 4096
EOF

echo
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Configuration complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo
echo "Next steps:"
echo "  1. Review your config: cat $CONFIG_FILE"
echo "  2. Restart Hermes Agent: systemctl restart hermes-agent (or restart manually)"
echo "  3. Test in Telegram: Send /model to see available models"
echo
echo -e "${YELLOW}Tip: Use /model in Telegram to switch between providers and models!${NC}"
echo

# Validate config if hermes config validate is available
if hermes config validate &> /dev/null; then
    echo "Validating configuration..."
    if hermes config validate; then
        echo -e "${GREEN}✓ Configuration is valid${NC}"
    else
        echo -e "${RED}✗ Configuration has errors. Please review $CONFIG_FILE${NC}"
    fi
fi

echo
echo "Setup complete!"
