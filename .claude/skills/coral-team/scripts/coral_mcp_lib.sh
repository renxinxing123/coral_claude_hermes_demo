#!/bin/bash
# Shared helpers to talk MCP (Streamable HTTP) to a Coral agent endpoint with plain curl.
# A Coral agent MCP URL looks like: http://localhost:5555/mcp/v1/<agentSecret>/mcp
# Coral replies with plain JSON (not SSE) for these calls, so we can pipe straight to jq.

CORAL_CURL=(curl --noproxy '*' -sS
  -H "Content-Type: application/json"
  -H "Accept: application/json, text/event-stream")

# Pull the JSON-RPC object out of a response (handles both plain-JSON and SSE "data:" framing).
_mcp_extract() { grep -E '^(data: )?\{' | sed 's/^data: //' | tail -1; }

# mcp_init <url> -> echoes the Mcp-Session-Id (also sends the initialized notification)
mcp_init() {
  local url="$1" hdr sid
  hdr=$(mktemp)
  "${CORAL_CURL[@]}" -D "$hdr" -o /dev/null -X POST "$url" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"coral-sh","version":"1"}}}'
  sid=$(grep -i '^mcp-session-id:' "$hdr" | tr -d '\r' | awk '{print $2}')
  rm -f "$hdr"
  if [ -z "$sid" ]; then echo "ERROR: no Mcp-Session-Id (bad URL or server down?)" >&2; return 1; fi
  "${CORAL_CURL[@]}" -o /dev/null -H "Mcp-Session-Id: $sid" -X POST "$url" \
    -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  printf '%s' "$sid"
}

# mcp_tool_call <url> <sid> <toolName> <argsJson> -> echoes clean JSON-RPC response
mcp_tool_call() {
  local url="$1" sid="$2" tool="$3" args="$4" body
  body=$(jq -nc --arg n "$tool" --argjson a "$args" \
    '{jsonrpc:"2.0",id:2,method:"tools/call",params:{name:$n,arguments:$a}}')
  "${CORAL_CURL[@]}" -H "Mcp-Session-Id: $sid" -X POST "$url" -d "$body" | _mcp_extract
}

# mcp_resource_read <url> <sid> <uri> -> echoes the resource text (markdown)
mcp_resource_read() {
  local url="$1" sid="$2" uri="$3" body
  body=$(jq -nc --arg u "$uri" '{jsonrpc:"2.0",id:3,method:"resources/read",params:{uri:$u}}')
  "${CORAL_CURL[@]}" -H "Mcp-Session-Id: $sid" -X POST "$url" -d "$body" | _mcp_extract \
    | jq -r '.result.contents[0].text'
}

# csv_to_json_array "a,b,c" -> ["a","b","c"] ; "" -> []
csv_to_json_array() {
  if [ -z "${1:-}" ]; then printf '[]'; else printf '%s' "$1" | jq -Rc 'split(",")|map(select(length>0))'; fi
}
