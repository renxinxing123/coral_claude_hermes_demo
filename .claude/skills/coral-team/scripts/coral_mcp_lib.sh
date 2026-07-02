#!/bin/bash
# Shared helpers to talk MCP (Streamable HTTP) to a Coral agent endpoint with plain curl.
# A Coral agent MCP URL looks like: http://localhost:5555/mcp/v1/<agentSecret>/mcp
# Coral replies with plain JSON (not SSE) for these calls.
#
# No `jq` required — JSON is built/parsed by the bundled _json.py (Python 3 stdlib only).
# Override the interpreter with CORAL_PY if needed (e.g. CORAL_PY=python).

CORAL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORAL_PY="${CORAL_PY:-python3}"
JSON_PY="$CORAL_LIB_DIR/coral_json.py"

CORAL_CURL=(curl --noproxy '*' -sS
  -H "Content-Type: application/json"
  -H "Accept: application/json, text/event-stream")

# --- JSON helpers (thin wrappers over _json.py, no jq) ---
json_kv()     { "$CORAL_PY" "$JSON_PY" kv "$@"; }   # build a JSON object from k v pairs
json_get()    { "$CORAL_PY" "$JSON_PY" get "$1"; }  # read stdin JSON, print value at dotted path
json_pretty() { "$CORAL_PY" "$JSON_PY" pretty; }    # read stdin JSON, pretty-print

# Pull the JSON-RPC object out of a response (handles both plain-JSON and SSE "data:" framing).
_mcp_extract() { grep -E '^(data: )?\{' | sed 's/^data: //' | tail -1; }

_need_py() {
  command -v "$CORAL_PY" >/dev/null 2>&1 && return 0
  echo "ERROR: '$CORAL_PY' not found. Need Python 3 (usually preinstalled). Set CORAL_PY to your python." >&2
  return 1
}

# mcp_init <url> -> echoes the Mcp-Session-Id (also sends the initialized notification)
mcp_init() {
  _need_py || return 1
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
# argsJson must already be valid JSON (build it with json_kv). toolName is a fixed identifier.
mcp_tool_call() {
  local url="$1" sid="$2" tool="$3" args="$4"
  local body="{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}"
  "${CORAL_CURL[@]}" -H "Mcp-Session-Id: $sid" -X POST "$url" -d "$body" | _mcp_extract
}

# mcp_resource_read <url> <sid> <uri> -> echoes the resource text (markdown)
mcp_resource_read() {
  local url="$1" sid="$2" uri="$3"
  local body="{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"resources/read\",\"params\":{\"uri\":\"$uri\"}}"
  "${CORAL_CURL[@]}" -H "Mcp-Session-Id: $sid" -X POST "$url" -d "$body" | _mcp_extract \
    | json_get 'result.contents.0.text'
}
