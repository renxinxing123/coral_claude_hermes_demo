#!/bin/bash
# Create a thread over MCP, masquerading as the agent that owns <AGENT_MCP_URL>.
#   usage: create_thread.sh <AGENT_MCP_URL> <threadName> [participantsCSV]
#   e.g.:  create_thread.sh "$ALICE_URL" "market-sync" "bob"
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/coral_mcp_lib.sh"

if [ $# -lt 2 ]; then
  echo "usage: $0 <AGENT_MCP_URL> <threadName> [participantsCSV]" >&2; exit 1
fi
URL="$1"; THREAD_NAME="$2"; PARTS=$(csv_to_json_array "${3:-}")

SID=$(mcp_init "$URL")
ARGS=$(jq -nc --arg t "$THREAD_NAME" --argjson p "$PARTS" '{threadName:$t,participantNames:$p}')
RESP=$(mcp_tool_call "$URL" "$SID" "coral_create_thread" "$ARGS")

THREAD=$(echo "$RESP" | jq -c '.result.structuredContent.thread // (.result.content[0].text|fromjson).thread')
echo "$THREAD" | jq .
echo "threadId=$(echo "$THREAD" | jq -r .id)"
