#!/bin/bash
# This script is launched by Coral Server via executable runtime.
# It patches the global Hermes config with the Coral MCP URL,
# then waits for the user to manually start Hermes.

GLOBAL_CONFIG="$HOME/.hermes/config.yaml"

echo "=== Coral Hermes Agent ==="
echo "Agent ID:       $CORAL_AGENT_ID"
echo "Session ID:     $CORAL_SESSION_ID"
echo "Connection URL: $CORAL_CONNECTION_URL"
echo ""

# --- Patch global config.yaml: inject coral MCP server ---
if [ -f "$GLOBAL_CONFIG" ]; then
    # Remove existing mcp_servers section
    perl -i -0pe 's/^mcp_servers:.*?(?=^\S|\z)//ms;' "$GLOBAL_CONFIG"

    # Append coral MCP server
    cat >> "$GLOBAL_CONFIG" << MCPEOF
mcp_servers:
  coral:
    url: "$CORAL_CONNECTION_URL"
    timeout: 1200
    connect_timeout: 30
MCPEOF

    echo ">>> Global config patched with coral MCP URL"
else
    echo "WARNING: Global config not found at $GLOBAL_CONFIG"
fi

echo ""
echo "============================================"
echo "  Hermes is ready! Start it with:"
echo ""
echo "    hermes chat"
echo ""
echo "============================================"

# Keep process alive (required by Coral Server)
while true; do
    sleep 3600
done
