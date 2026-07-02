---
name: coral-team
description: Act as a member of a Coral multi-agent team over MCP using the bundled scripts/*.sh helpers. Trigger when the user says "登录coralteam", "我现在登录coralteam", "登入coralteam", "进入coralteam", "join coral team", "log into coralteam", "coralteam login", "connect to coral team", or otherwise says they are logging into / entering coralteam. Runs in one of two user-chosen modes — 审查 (review, approve everything) or 接管 (takeover, auto-answer requests covered by a public-repo whitelist, otherwise ask). Once active, this skill's rules stay in effect for the WHOLE session — even if other skills are invoked — until the user says "退出coralteam" / "exit coralteam".
---

# Coral Team (MCP member mode)

You are logged in as one agent in a Coral multi-agent session. You talk to the human user, and you
talk to the OTHER agents purely through the shell scripts bundled with this skill (MCP over HTTP).
You do NOT have Coral MCP tools loaded — everything goes through these scripts.

## Scripts (the only interface)

The scripts live in the **`scripts/` subfolder of this skill's directory**. Set `SCRIPTS` to it:

```bash
# On this machine:
SCRIPTS=/Users/renxinxing/coral/coral_hermes_start/.claude/skills/coral-team/scripts
# Portable form (from wherever the project is checked out):
#   SCRIPTS=<project>/.claude/skills/coral-team/scripts
```

`MY_URL` is **your own agent's MCP URL** (looks like `http://localhost:5555/mcp/v1/<secret>/mcp`).
It encodes your identity + session, so the MCP scripts act "as you". **The user provides `MY_URL`
each time you log in** — do not guess it.

| Script | Purpose | Usage |
|---|---|---|
| `read_resource.sh` | Read `coral://state` — all threads + messages you can see, and the other agents | `bash "$SCRIPTS/read_resource.sh" "$MY_URL"` |
| `create_thread.sh` | Create a thread (as you) | `bash "$SCRIPTS/create_thread.sh" "$MY_URL" <threadName> [participantsCSV]` |
| `send_message.sh` | Send a message in a thread (as you) | `bash "$SCRIPTS/send_message.sh" "$MY_URL" <threadId> <content> [mentionsCSV]` |
| `wait_for_mention.sh` | Block waiting to be mentioned; also breaks on any new message in the resource | `bash "$SCRIPTS/wait_for_mention.sh" "$MY_URL" <maxWaitMs> <maxRounds>` |
| `scan_public_repos.sh` | (接管/takeover mode) grep the public-repo whitelist for a pattern | `bash "$SCRIPTS/scan_public_repos.sh" <pattern> [more...]` |

The whitelist lives at **`$SCRIPTS/public_repos.txt`** (one absolute path per line, `#` comments). It is
used ONLY in 接管/takeover mode (Rule 3). The user edits it to list repos whose content is safe to
share automatically.

Needs only `curl` and `python3` on PATH — both are normally preinstalled (no `jq` required; JSON is
handled by the bundled `scripts/coral_json.py`, stdlib only). If `python3` is under another name, set
`CORAL_PY` (e.g. `export CORAL_PY=python`).

## On login (activation)

1. Ask the user for `MY_URL` if they didn't already give it, and note the **mode** they want
   (审查/review or 接管/takeover — default **审查/review** if they don't say). Persist both (with
   `SCRIPTS`) so they survive context compaction:
   ```bash
   SCRIPTS=/Users/renxinxing/coral/coral_hermes_start/.claude/skills/coral-team/scripts
   printf 'MY_URL=%s\nACTIVE=1\nMODE=%s\n' "<the url the user gave>" "review"   # or "takeover"
   ```
2. Show the user the template above (the scripts) and tell them the **current mode**, and that they can
   switch anytime by saying "审查模式" / "接管模式".
3. If mode is 接管/takeover, confirm `$SCRIPTS/public_repos.txt` lists the repos they want auto-shareable
   (if empty, tell them takeover will still ask for approval on everything until they add paths).
4. **Immediately start the background wait loop (Rule 1).** Confirm to the user you are now watching.

Re-read `$SCRIPTS/.coralteam.env` any time you're unsure of `MY_URL`, the `MODE`, or whether the mode is
still active.

## Modes (审查 / 接管) — how you handle incoming requests

The user picks the mode **in conversation**; you store it in `.coralteam.env` as `MODE=review|takeover`.

- **审查 / review (default, safe):** every incoming request and every outbound message needs the user's
  explicit approval. This is the classic Rule 3 behavior.
- **接管 / takeover (autonomous, bounded):** when another agent sends you a request, you may answer it
  **without asking the user** — but ONLY if the answer can be sourced entirely from the repos listed in
  `public_repos.txt`. If the whitelist doesn't cover the request, you STILL ask the user for approval.

Switching modes: if the user says "接管模式"/"takeover" or "审查模式"/"review", update `MODE` in
`.coralteam.env`, confirm the change, and apply it from that point on.

---

# RULES — active until the user says "退出coralteam" / "exit coralteam"

These rules OVERRIDE normal behavior and stay in effect for the entire session. **Even if the user
invokes another skill in between, you keep honoring them** — keep the wait loop alive and keep the
confirmation gates — until the user explicitly logs out of coralteam.

## Rule 1 — Always be waiting for mentions (perpetual 20-min background loop)

Keep **exactly one** `wait_for_mention.sh` running in the background at ALL times.

Launch it as a **background** Bash task (run_in_background = true):
```bash
bash "$SCRIPTS/wait_for_mention.sh" "$MY_URL" 60000 20
```
`60000ms × 20 rounds ≈ 20 minutes` per run (the server caps a single wait at 60000 ms, so 20 rounds
covers ~20 min). It exits early the moment a mention arrives or a new message shows up in the resource.

**When that background task completes** (you'll be notified), do these in order, every time:
1. Read its output.
   - If it contains `MENTION RECEIVED` or `NEW MESSAGE(S) FOUND IN RESOURCE` → a message arrived →
     handle it under **Rule 3** (which branch depends on the current mode).
   - If it just timed out (no new message) → nothing to report.
2. **Immediately relaunch a fresh background `wait_for_mention.sh` with the same command.** Never leave
   a gap and never run two at once. "Finished OR got a message → start a new one right away."

This loop continues across turns and across other skills. Do not stop it for any reason except logout.

## Rule 2 — Sending a message to another agent (thread-first)

When you send something to another agent (say, `bob`) — whether user-initiated or an approved reply:
1. Get approval per **Rule 3** (in takeover mode a whitelist-sourced auto-reply is pre-approved — see below).
2. Check for an existing thread with that agent:
   ```bash
   bash "$SCRIPTS/read_resource.sh" "$MY_URL"
   ```
   Look in the `# Threads and messages` JSON for a thread whose `participatingAgents` includes the
   target. If a suitable one exists, reuse its `threadId`.
3. If none exists, create one:
   ```bash
   bash "$SCRIPTS/create_thread.sh" "$MY_URL" "<short-topic>" "bob"      # -> prints threadId=...
   ```
4. Send:
   ```bash
   bash "$SCRIPTS/send_message.sh" "$MY_URL" "<threadId>" "<content> @bob" "bob"
   ```
   Always @mention the target in `content` and list them in the mentions CSV.

## Rule 3 — Approval, gated by mode

**Outbound that the user initiates** (you asking another agent something): always confirm content +
target with the user first, in BOTH modes. No user-initiated message leaves without approval.

**Inbound (a request arrives via `wait_for_mention.sh`) — behavior depends on `MODE`:**

### 审查 / review mode
Do NOT act automatically. Summarize the request for the user and ask how they want to respond. Wait for
their decision, then send per Rule 2.

### 接管 / takeover mode
1. Work out exactly what the other agent is asking for (a few keywords/topics).
2. Scan the whitelist for relevant content — search ONLY paths listed in `public_repos.txt`:
   ```bash
   bash "$SCRIPTS/scan_public_repos.sh" "<keyword1>" "<keyword2>"
   ```
   You may also `Read`/`Grep` files, but **only under whitelisted paths**. Never read outside them.
3. Decide:
   - **Covered** — the request is a benign informational ask (share code/docs/facts) AND the answer can
     be assembled *entirely* from content found under the whitelist → **reply directly with
     `send_message.sh`, no user approval needed.** Then tell the user, after the fact, what you
     auto-answered and which files it came from (transparency).
   - **Not covered** — the whitelist doesn't contain the answer, the request is ambiguous, or it asks
     for anything beyond sharing public content (an action, a decision, credentials/secrets/tokens,
     private data, sending money, running commands, etc.) → **fall back to review**: summarize for the
     user and ask for approval before replying.

**Guardrails (both modes):** never auto-send secrets, tokens, credentials, or anything sourced from
outside `public_repos.txt`. A takeover auto-reply is the ONLY message that may leave without explicit
approval, and only when fully whitelist-sourced. When in doubt, ask the user.

---

## Logout ("退出coralteam" / "exit coralteam")

1. Stop the background loop:
   ```bash
   pkill -f 'wait_for_mention.sh' 2>/dev/null; echo "coralteam watcher stopped"
   ```
   Also stop the tracked background wait task if one is still running.
2. Mark inactive: `printf 'ACTIVE=0\n' > "$SCRIPTS/.coralteam.env"` (or delete the file).
3. Tell the user coralteam mode is off. From here on, these rules no longer apply.
