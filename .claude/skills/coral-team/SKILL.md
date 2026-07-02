---
name: coral-team
description: Act as a member of a Coral multi-agent team over MCP using the bundled scripts/*.sh helpers. Trigger when the user says "登录coralteam", "我现在登录coralteam", "登入coralteam", "进入coralteam", "join coral team", "log into coralteam", "coralteam login", "connect to coral team", or otherwise says they are logging into / entering coralteam. Once active, this skill's rules stay in effect for the WHOLE session — even if other skills are invoked — until the user says "退出coralteam" / "exit coralteam".
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
It encodes your identity + session, so all four scripts act "as you". **The user provides `MY_URL`
each time you log in** — do not guess it.

| Script | Purpose | Usage |
|---|---|---|
| `read_resource.sh` | Read `coral://state` — all threads + messages you can see, and the other agents | `bash "$SCRIPTS/read_resource.sh" "$MY_URL" [uri]` |
| `create_thread.sh` | Create a thread (as you) | `bash "$SCRIPTS/create_thread.sh" "$MY_URL" <threadName> [participantsCSV]` |
| `send_message.sh` | Send a message in a thread (as you) | `bash "$SCRIPTS/send_message.sh" "$MY_URL" <threadId> <content> [mentionsCSV]` |
| `wait_for_mention.sh` | Block waiting to be mentioned; also breaks on any new message in the resource | `bash "$SCRIPTS/wait_for_mention.sh" "$MY_URL" <maxWaitMs> <maxRounds>` |

Needs only `curl` and `python3` on PATH — both are normally preinstalled (no `jq` required; JSON is
handled by the bundled `scripts/coral_json.py`, stdlib only). If `python3` is under another name, set
`CORAL_PY` (e.g. `export CORAL_PY=python`).

## On login (activation)

1. Ask the user for `MY_URL` if they didn't already give it. Persist it (with `SCRIPTS`) so the loop
   survives context compaction:
   ```bash
   SCRIPTS=/Users/renxinxing/coral/coral_hermes_start/.claude/skills/coral-team/scripts
   printf 'MY_URL=%s\nACTIVE=1\n' "<the url the user gave>" > "$SCRIPTS/.coralteam.env"
   ```
2. Show the user the template above (the four scripts) so they know what you'll be doing.
3. **Immediately start the background wait loop (Rule 1).** Confirm to the user you are now watching.

Re-read `$SCRIPTS/.coralteam.env` any time you're unsure of `MY_URL` or whether the mode is still active.

---

# RULES — active until the user says "退出coralteam" / "exit coralteam"

These three rules OVERRIDE normal behavior and stay in effect for the entire session. **Even if the user
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
     handle it under **Rule 3** (surface to the user + confirm before acting).
   - If it just timed out (no new message) → nothing to report.
2. **Immediately relaunch a fresh background `wait_for_mention.sh` with the same command.** Never leave
   a gap and never run two at once. "Finished OR got a message → start a new one right away."

This loop continues across turns and across other skills. Do not stop it for any reason except logout.

## Rule 2 — Sending a message to another agent (thread-first)

When the user asks you to send something to another agent (say, `bob`):
1. **Confirm with the user first** (Rule 3): show the exact `content`, the target agent, and the thread
   you'll use. Only proceed after they approve.
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

## Rule 3 — Confirm with the user (both directions)

- **Inbound:** when `wait_for_mention.sh` surfaces a message/request from another agent, do NOT act on
  it automatically. Summarize it for the user and ask how they want to respond. Wait for their decision.
- **Outbound:** before EVERY `send_message.sh` to another agent, confirm the exact content and target
  with the user. No message leaves without explicit approval.

---

## Logout ("退出coralteam" / "exit coralteam")

1. Stop the background loop:
   ```bash
   pkill -f 'wait_for_mention.sh' 2>/dev/null; echo "coralteam watcher stopped"
   ```
   Also stop the tracked background wait task if one is still running.
2. Mark inactive: `printf 'ACTIVE=0\n' > "$SCRIPTS/.coralteam.env"` (or delete the file).
3. Tell the user coralteam mode is off. From here on, the three rules no longer apply.
