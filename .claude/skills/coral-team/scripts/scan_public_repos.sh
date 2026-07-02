#!/bin/bash
# Search the TAKEOVER-mode public-repo whitelist (scripts/public_repos.txt) for a pattern.
# Prints file:line matches so the agent can judge whether an incoming request is answerable
# from public content — and, in 接管/takeover mode, may then auto-reply from what it finds.
#
#   usage: scan_public_repos.sh <pattern> [morePatterns ...]
#   e.g.:  scan_public_repos.sh "rate limit" "throttle"
#
# Only paths listed in public_repos.txt are ever searched. If the whitelist is empty, nothing
# is searchable and the agent must fall back to asking the user for approval.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="$DIR/public_repos.txt"

if [ $# -lt 1 ]; then echo "usage: $0 <pattern> [pattern2 ...]" >&2; exit 1; fi
if [ ! -f "$LIST" ]; then echo "(no public_repos.txt — takeover whitelist is empty)"; exit 0; fi

paths=()
while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%%#*}"                                                                   # strip trailing comment
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"   # trim
  [ -z "$line" ] && continue
  if [ -e "$line" ]; then paths+=("$line"); else echo "WARN: path not found, skipping: $line" >&2; fi
done < "$LIST"

if [ ${#paths[@]} -eq 0 ]; then echo "(public repo whitelist is empty — nothing to scan)"; exit 0; fi

pats=(); for p in "$@"; do pats+=(-e "$p"); done
echo ">> scanning ${#paths[@]} whitelisted path(s) for: $*"
grep -rniI --exclude-dir=.git "${pats[@]}" "${paths[@]}" 2>/dev/null | head -200 || true
