#!/bin/bash
# Send a message in a thread over MCP, masquerading as the agent that owns <AGENT_MCP_URL>.
#   usage: send_message.sh <AGENT_MCP_URL> <threadId> <content> [mentionsCSV]
#   e.g.:  send_message.sh "$ALICE_URL" "$TID" "hi bob" "bob"
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/coral_mcp_lib.sh"

if [ $# -lt 3 ]; then
  echo "usage: $0 <AGENT_MCP_URL> <threadId> <content> [mentionsCSV]" >&2; exit 1
fi
URL="$1"; TID="$2"; CONTENT="$3"; MENTIONS_CSV="${4:-}"

SID=$(mcp_init "$URL") || exit 1
ARGS=$(json_kv threadId "$TID" content "$CONTENT" @mentions "$MENTIONS_CSV")
RESP=$(mcp_tool_call "$URL" "$SID" "coral_send_message" "$ARGS")

OUT=$(printf '%s' "$RESP" | json_get 'result.structuredContent')
if [ -z "$OUT" ]; then echo "unexpected response:"; printf '%s\n' "$RESP"; exit 1; fi
printf '%s' "$OUT" | json_pretty; echo
