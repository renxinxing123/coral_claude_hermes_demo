#!/bin/bash
# Read an MCP resource as the agent that owns <AGENT_MCP_URL>.
# Default resource is coral://state, which shows all threads and messages this agent can see
# (plus the other agents in the session).
#   usage: read_resource.sh <AGENT_MCP_URL> [resourceUri]
#   e.g.:  read_resource.sh "$MY_URL"                 # -> coral://state
#          read_resource.sh "$MY_URL" coral://instruction
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/coral_mcp_lib.sh"

if [ $# -lt 1 ]; then echo "usage: $0 <AGENT_MCP_URL> [resourceUri]" >&2; exit 1; fi
URL="$1"; URI="${2:-coral://state}"

SID=$(mcp_init "$URL") || exit 1
mcp_resource_read "$URL" "$SID" "$URI"
