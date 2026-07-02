#!/bin/bash
# Wait to be mentioned, as the agent that owns <AGENT_MCP_URL>.
#
# Logic (as requested):
#   1. Before looping, read the coral://state resource and record how many messages
#      are currently visible in ALL threads of this session (the baseline).
#   2. Loop forever:
#        - call coral_wait_for_mention (blocks up to maxWaitMs)
#        - if it returns a message  -> BREAK (mention received)
#        - if it times out          -> re-read coral://state; if the message count
#          grew past the baseline   -> BREAK (a new message appeared in the resource)
#        - otherwise keep looping.
#   Only those two conditions break the loop.
#
#   usage: wait_for_mention.sh <AGENT_MCP_URL> [maxWaitMs=8000] [maxRounds=0]
#          maxRounds=0 means "loop forever" (default). Set >0 as a safety cap for testing.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/coral_mcp_lib.sh"

if [ $# -lt 1 ]; then
  echo "usage: $0 <AGENT_MCP_URL> [maxWaitMs=8000] [maxRounds=0]" >&2; exit 1
fi
URL="$1"; MAX_WAIT_MS="${2:-8000}"; MAX_ROUNDS="${3:-0}"

# count "messageText" occurrences = number of messages visible in coral://state
count_messages() { { grep -o '"messageText"' || true; } | wc -l | tr -d ' '; }

SID=$(mcp_init "$URL") || exit 1

STATE=$(mcp_resource_read "$URL" "$SID" "coral://state")
BASELINE=$(printf '%s' "$STATE" | count_messages)
echo ">> baseline: $BASELINE message(s) currently visible in the session"
echo ">> waiting for a mention (maxWaitMs=$MAX_WAIT_MS per round) ..."

WAIT_ARGS=$(json_kv '#maxWaitMs' "$MAX_WAIT_MS")
round=0
while true; do
  round=$((round + 1))
  RESP=$(mcp_tool_call "$URL" "$SID" "coral_wait_for_mention" "$WAIT_ARGS")

  MSG=$(printf '%s' "$RESP" | json_get 'result.structuredContent.message' 2>/dev/null)
  if [ -n "$MSG" ]; then
    echo ""
    echo "=== [round $round] MENTION RECEIVED (via coral_wait_for_mention) ==="
    printf '%s' "$MSG" | json_pretty; echo
    break
  fi

  # timed out -> check the resource for any new message
  STATE=$(mcp_resource_read "$URL" "$SID" "coral://state")
  NOW=$(printf '%s' "$STATE" | count_messages)
  echo "[round $round] wait timed out; messages in resource now: $NOW (baseline $BASELINE)"
  if [ "$NOW" -gt "$BASELINE" ]; then
    echo ""
    echo "=== [round $round] NEW MESSAGE(S) FOUND IN RESOURCE (coral://state) ==="
    printf '%s\n' "$STATE"
    break
  fi

  if [ "$MAX_ROUNDS" -gt 0 ] && [ "$round" -ge "$MAX_ROUNDS" ]; then
    echo ">> reached maxRounds=$MAX_ROUNDS without a new message, stopping."
    break
  fi
done
