#!/bin/bash
# This script is launched by Coral Server via executable runtime.
# It writes the Coral MCP config so Claude Code can connect,
# then waits for the user to manually start Claude Code.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_SETTINGS_DIR="$SCRIPT_DIR/.claude"
mkdir -p "$CLAUDE_SETTINGS_DIR"

echo "=== Coral Claude Code Agent ==="
echo "Agent ID:       $CORAL_AGENT_ID"
echo "Session ID:     $CORAL_SESSION_ID"
echo "Connection URL: $CORAL_CONNECTION_URL"
echo ""

# --- Write .mcp.json for MCP server discovery ---
cat > "$SCRIPT_DIR/.mcp.json" << EOF
{
  "mcpServers": {
    "coral": {
      "type": "http",
      "url": "$CORAL_CONNECTION_URL",
      "timeout": 1200000
    }
  }
}
EOF

# --- Write settings to auto-trust coral MCP server ---
cat > "$CLAUDE_SETTINGS_DIR/settings.local.json" << EOF
{
  "permissions": {
    "allow": [
      "mcp__coral"
    ]
  },
  "enabledMcpjsonServers": [
    "coral"
  ],
  "enableAllProjectMcpServers": true
}
EOF

echo ">>> .mcp.json and settings written"
echo ""
echo "============================================"
echo "  Claude Code is ready! Start it with:"
echo ""
echo "    cd $SCRIPT_DIR && claude"
echo ""
echo "============================================"

# Keep process alive (required by Coral Server)
while true; do
    sleep 3600
done
