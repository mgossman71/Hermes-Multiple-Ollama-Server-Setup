#!/bin/bash
# verify-ollama-setup.sh
# Verify that multiple Ollama providers are configured and accessible

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Hermes Multiple Ollama Setup Verification              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo

CONFIG_FILE="$HOME/.hermes/config.yaml"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗ Config file not found at $CONFIG_FILE${NC}"
    echo "  Run setup-ollama-providers.sh first"
    exit 1
fi

echo -e "${GREEN}✓ Config file exists${NC}"
echo

# Parse providers from config
echo "Checking configured providers..."
echo "───────────────────────────────────────────────────────────"

# Extract provider names and URLs
providers=$(grep -E "^  [a-zA-Z0-9-]+:" "$CONFIG_FILE" | grep -v "models:" | grep -v "telegram:" | grep -v "defaults:" | grep -v "failover:" | grep -v "performance:" | awk -F: '{print $1}' | tr -d ' ')

for provider in $providers; do
    echo
    echo "Provider: $provider"
    
    # Get base_url
    base_url=$(awk "/^  $provider:/,/^[ ]{2}[a-z]+:/{if(/base_url:/) print}" "$CONFIG_FILE" | awk '{print $2}')
    
    if [ -z "$base_url" ]; then
        echo -e "  ${YELLOW}! No base_url found${NC}"
        continue
    fi
    
    echo "  URL: $base_url"
    
    # Test connectivity
    if curl -s --connect-timeout 5 "$base_url/models" > /dev/null 2>&1 || curl -s --connect-timeout 5 "${base_url%/v1}/api/tags" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Accessible${NC}"
        
        # List models
        echo "  Models:"
        if [[ "$base_url" == *"ollama.com"* ]]; then
            # Cloud provider
            models=$(curl -s "$base_url/models" | jq -r '.data[]?.id // empty' 2>/dev/null | head -5)
        else
            # Local provider
            models=$(curl -s "${base_url%/v1}/api/tags" | jq -r '.models[].name' 2>/dev/null | head -5)
        fi
        
        if [ -n "$models" ]; then
            echo "$models" | sed 's/^/    • /'
        else
            echo -e "    ${YELLOW}Unable to fetch model list${NC}"
        fi
    else
        echo -e "  ${RED}✗ Not accessible${NC}"
        echo "    Check if the server is running and firewall allows connections"
    fi
done

echo
echo "───────────────────────────────────────────────────────────"
echo

# Check Telegram configuration
echo "Checking Telegram configuration..."
telegram_enabled=$(grep -A5 "^telegram:" "$CONFIG_FILE" | grep "enabled:" | awk '{print $2}')
model_switching=$(grep -A5 "^telegram:" "$CONFIG_FILE" | grep "model_switching:" | awk '{print $2}')

if [ "$telegram_enabled" = "true" ]; then
    echo -e "${GREEN}✓ Telegram enabled${NC}"
else
    echo -e "${YELLOW}! Telegram not enabled${NC}"
fi

if [ "$model_switching" = "true" ]; then
    echo -e "${GREEN}✓ Model switching enabled${NC}"
else
    echo -e "${YELLOW}! Model switching not enabled${NC}"
fi

echo

# Check default provider
echo "Checking default configuration..."
default_provider=$(grep -A10 "^defaults:" "$CONFIG_FILE" | grep "provider:" | awk '{print $2}')
default_model=$(grep -A10 "^defaults:" "$CONFIG_FILE" | grep "model:" | awk '{print $2}')

if [ -n "$default_provider" ] && [ -n "$default_model" ]; then
    echo -e "${GREEN}✓ Default: $default_provider/$default_model${NC}"
else
    echo -e "${YELLOW}! No default provider/model configured${NC}"
fi

echo
echo "───────────────────────────────────────────────────────────"
echo

# Check if Hermes is running
echo "Checking Hermes Agent status..."
if pgrep -x "hermes-agent" > /dev/null; then
    echo -e "${GREEN}✓ Hermes Agent is running${NC}"
else
    echo -e "${YELLOW}! Hermes Agent is not running${NC}"
    echo "  Start it with: hermes-agent start"
fi

echo
echo "═══════════════════════════════════════════════════════════"
echo "Verification Complete"
echo "═══════════════════════════════════════════════════════════"
echo
echo "To test model switching in Telegram:"
echo "  1. Open your Hermes bot chat"
echo "  2. Send: /model"
echo "  3. Select a model from the list"
echo "  4. Send a test message"
echo
