#!/bin/bash
# Read the coral://state resource as the agent that owns <AGENT_MCP_URL>.
# coral://state shows all threads and messages this agent can see, plus the other agents.
#   usage: read_resource.sh <AGENT_MCP_URL>
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/coral_mcp_lib.sh"

if [ $# -lt 1 ]; then echo "usage: $0 <AGENT_MCP_URL>" >&2; exit 1; fi
URL="$1"

SID=$(mcp_init "$URL") || exit 1
mcp_resource_read "$URL" "$SID" "coral://state"; echo
