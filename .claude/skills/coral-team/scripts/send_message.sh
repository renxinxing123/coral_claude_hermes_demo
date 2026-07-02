#!/bin/bash
# Send a message in a thread over MCP, masquerading as the agent that owns <AGENT_MCP_URL>.
#   usage: send_message.sh <AGENT_MCP_URL> <threadId> <content> [mentionsCSV]
#   e.g.:  send_message.sh "$ALICE_URL" "$TID" "hi bob" "bob"
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/coral_mcp_lib.sh"

if [ $# -lt 3 ]; then
  echo "usage: $0 <AGENT_MCP_URL> <threadId> <content> [mentionsCSV]" >&2; exit 1
fi
URL="$1"; TID="$2"; CONTENT="$3"; MENTIONS=$(csv_to_json_array "${4:-}")

SID=$(mcp_init "$URL")
ARGS=$(jq -nc --arg t "$TID" --arg c "$CONTENT" --argjson m "$MENTIONS" \
  '{threadId:$t,content:$c,mentions:$m}')
RESP=$(mcp_tool_call "$URL" "$SID" "coral_send_message" "$ARGS")

echo "$RESP" | jq '.result.structuredContent // (.result.content[0].text|fromjson)'
