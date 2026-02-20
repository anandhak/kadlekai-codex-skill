---
name: kadlekai-time-tracking
description: Track time in Kadlekai from a Codex session — start/stop timers, log work, reconcile session worklogs, and query time reports; use when user asks to start a timer, stop a timer, log hours, reconcile worklogs, check timer status, or generate a time report.
---

# Kadlekai Time Tracking — Codex Skill

Use this skill to track time in Kadlekai directly from Codex sessions. It covers reconciling session work into worklogs, controlling timers, and querying reports.

---

## Setup

### 1. Add Kadlekai MCP to Codex

Add the following to `~/.codex/config.toml`:

```toml
[mcp_servers.kadlekai]
command = "node"
args = ["/absolute/path/to/kadlekai/mcp-server/dist/index.js"]

[mcp_servers.kadlekai.env]
KADLEKAI_API_TOKEN = "your_token_here"
KADLEKAI_API_URL = "https://kadle.beskar.tech"
```

Or use the CLI if your Codex version supports it:

```bash
codex mcp add kadlekai \
  --env KADLEKAI_API_TOKEN=your_token \
  --env KADLEKAI_API_URL=https://kadle.beskar.tech \
  -- node /absolute/path/to/kadlekai/mcp-server/dist/index.js
```

### 2. Generate an API Token

From the Kadlekai Rails app:

```bash
bin/rails runner "
user = User.find_by(email: 'your@email.com')
auth_service = AuthenticationService.new(current_user: user, request: nil)
result = auth_service.create_api_key_for_user(user, client_name: 'Codex', expiry_hours: 720)
puts 'Token: ' + result[:auth_token]
"
```

### 3. Install this skill

```bash
mkdir -p ~/.codex/skills/kadlekai-time-tracking
cp /path/to/kadlekai/codex/skills/kadlekai-time-tracking/SKILL.md \
   ~/.codex/skills/kadlekai-time-tracking/SKILL.md
```

> **URL drift fix:** If the MCP server returns `ENOTFOUND`, an old install wrote `kadle.ai`
> to your config. Fix it:
> ```bash
> sed -i '' 's|kadle\.ai|kadle.beskar.tech|g' ~/.codex/config.toml
> ```
> Then restart Codex.

---

## Available MCP Tools

| Tool | Description |
|---|---|
| `start_timer` | Start a new timer (always call get_running_timer first) |
| `stop_timer` | Stop the running timer (requires project + description) |
| `get_running_timer` | Check if a timer is running and its elapsed time |
| `create_worklog` | Create a completed time entry for a past period |
| `update_worklog` | Update an existing worklog (description, times, project) |
| `delete_worklog` | Delete a worklog entry |
| `list_worklogs` | List entries filtered by date, project, or status |
| `list_projects` | List all active projects in the workspace |
| `generate_report` | Time summary for a date range or predefined period |
| `process_natural_language_command` | Parse and execute a natural language time command |

---

## Reconciliation Flow

Use when the user says "reconcile my worklogs", "log today's work", or "log this session".

Since Codex has no hook events, reconciliation is session-based: ask the user to describe what they did.

### Steps

1. **Gather session context** — ask:
   > "When did you start working today? What did you work on? Give me a start time, end time (or duration), and a brief description."

2. **Check existing entries** — call `list_worklogs` for today. For each returned entry,
   compare its `[start_time, end_time]` against the proposed new entry's time range.
   **An overlap exists when: `proposed_start < existing_end AND proposed_end > existing_start`.**
   Note any overlapping entries — they are used in step 5.

3. **Suggest a project** — call `list_projects`, then fuzzy-match against:
   - The current repo directory name (e.g. `kadlekai` → project named "Kadlekai")
   - Any project or task names mentioned by the user

4. **Confirm before creating** — if NO overlapping entries were found in step 2, present a
   summary and ask:
   > "I'll log X hours to project Y — description: 'Z'. Does that look right?"
   Wait for explicit confirmation before calling `create_worklog`.
   **If any overlap was found in step 2, skip this step and go directly to step 5.**

5. **Handle overlaps** — if a new entry overlaps an existing worklog, show both and ask the user:
   > "Entry A already covers [X minutes] of this time. What should I do?
   > 1. Keep existing  2. Replace existing  3. Split into two entries"
   Never auto-merge or auto-delete without user approval.

6. **Create the entry** — call `create_worklog` with confirmed params.

7. **Record reconcile time** — write `{"last_reconcile_at": "<ISO timestamp>"}` to `~/.codex/kadle/state.json`.

---

## Time Commands (Direct)

| User says | What to do |
|---|---|
| "start timer [description]" | `get_running_timer` → warn if one is already running → `start_timer` |
| "stop timer" | call `get_running_timer` first; if none active, tell user; otherwise `stop_timer` (ask for project/description if missing) |
| "log X hours [description]" | Ask for project, compute start/end from now, `create_worklog` |
| "timer status" | **Call `get_running_timer` directly.** Display elapsed time and description. |
| "report [today/this week/this month]" | `generate_report` with the matching time_frame |
| "update worklog [id]" | Ask what to change, then `update_worklog` |
| "delete worklog [id]" | Show entry details, ask confirmation, THEN `delete_worklog` |

> **CRITICAL — direct timer commands:** The commands "start timer", "stop timer", and
> "timer status" MUST call `start_timer`, `stop_timer`, and `get_running_timer` directly.
> NEVER route these through `process_natural_language_command`. The NL processor may
> mis-classify them (e.g. "timer status" → `intent: start_timer`) and take the wrong action.
> `process_natural_language_command` is only for free-form commands that do not match the
> explicit patterns in the table above.

---

## Behavioural Rules

> **SAFETY — delete:** Before calling `delete_worklog`, you MUST present the worklog details
> and ask: "Are you sure you want to delete this worklog? (yes/no)" Then wait for an explicit
> "yes" or "confirm" in the user's reply. Never call `delete_worklog` without this step.

> **SAFETY — overlaps:** Before calling `create_worklog` or `update_worklog`, verify the
> time range against existing entries using: `new_start < existing_end AND new_end > existing_start`.
> If any overlap exists, STOP — do NOT proceed to confirmation. Present both entries with the
> overlap duration in minutes, then ask: "Keep existing / replace existing / split?"
> Never create, update, or delete worklogs to resolve an overlap without an explicit user
> instruction in the same turn.

> **RECOVERY — orphaned timer:** If `start_timer` fails with a conflict or "only one running
> worklog" error despite `get_running_timer` returning no active timer:
> 1. Call `list_worklogs` with `status: "running"` to find any orphaned timers.
> 2. If entries are returned, show them and ask: "Found a running timer that wasn't visible — stop it first?"
> 3. If `list_worklogs` also returns empty (both endpoints disagree with the API error),
>    tell the user: "The server reports a running timer but neither get_running_timer nor
>    list_worklogs can see it — this is a backend visibility bug. Wait a moment and try again,
>    or contact support if it persists." Do NOT retry `start_timer` automatically.

- **Never use `process_natural_language_command` for start/stop/status timer commands.** Always call `get_running_timer`, `start_timer`, or `stop_timer` directly.
- **Always confirm project** before creating or updating a worklog. Never assume.
- **Always confirm on overlaps** — never auto-merge, auto-split, or auto-delete.
- **Keep descriptions terse** — ≤ 100 chars. Prefer issue refs like `"Fix #42"` over prose.
- **Omit timezone** — the server uses the user's stored preference.
- **Running timer check** — before starting a new timer, always call `get_running_timer` first and warn if one is already active.
- **State file** — write reconcile timestamps to `~/.codex/kadle/state.json` (create dir if needed).
