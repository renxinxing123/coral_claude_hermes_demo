#!/bin/bash
# Create a thread over MCP, masquerading as the agent that owns <AGENT_MCP_URL>.
#   usage: create_thread.sh <AGENT_MCP_URL> <threadName> [participantsCSV]
#   e.g.:  create_thread.sh "$ALICE_URL" "market-sync" "bob"
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/coral_mcp_lib.sh"

if [ $# -lt 2 ]; then
  echo "usage: $0 <AGENT_MCP_URL> <threadName> [participantsCSV]" >&2; exit 1
fi
URL="$1"; THREAD_NAME="$2"; PARTS_CSV="${3:-}"

SID=$(mcp_init "$URL") || exit 1
ARGS=$(json_kv threadName "$THREAD_NAME" @participantNames "$PARTS_CSV")
RESP=$(mcp_tool_call "$URL" "$SID" "coral_create_thread" "$ARGS")

THREAD=$(printf '%s' "$RESP" | json_get 'result.structuredContent.thread')
if [ -z "$THREAD" ]; then echo "unexpected response:"; printf '%s\n' "$RESP"; exit 1; fi
printf '%s' "$THREAD" | json_pretty; echo
echo "threadId=$(printf '%s' "$RESP" | json_get 'result.structuredContent.thread.id')"
