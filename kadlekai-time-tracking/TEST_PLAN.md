# Kadlekai Time Tracking Skill — Test Plan

Paste this into a Codex CLI session (or run via `codex/bin/kadle-codex`).
Work through each test case in order. Mark each as PASS or FAIL.

---

## Setup Check

Before running tests, confirm:
- [ ] `KADLEKAI_API_TOKEN` is set
- [ ] `KADLEKAI_API_URL` points to https://kadle.beskar.tech
- [ ] MCP server is reachable: ask "what's my current timer status?"

---

## Test 1 — Timer Status

**Prompt to Codex:**
> Check my current timer status.

**Expected:** Codex calls `get_running_timer` and reports either a running timer with description + elapsed time, or "no timer running". No errors.

---

## Test 2 — Generate Report (was crashing)

**Prompt to Codex:**
> Show me a time report for this week.

**Expected:** Codex calls `generate_report` with `time_frame: "this_week"` and returns a summary table showing total hours, entries count, and up to 50 entry details. Must NOT crash with "slice is not a function".

---

## Test 3 — Start and Stop a Timer

**Prompt to Codex:**
> Start a timer for "Test run".

**Expected:** Codex checks for an existing running timer first (`get_running_timer`), warns if one is active, then calls `start_timer`. Confirms timer started.

**Then:**
> Stop the timer.

**Expected:** Codex asks which project to log to (if not already set), then calls `stop_timer`. Confirms stopped with duration.

---

## Test 4 — Delete Confirmation Safety (key regression test)

**Setup:** First ask Codex to list today's worklogs and pick an ID to delete.
> List my worklogs for today.

Note one worklog ID from the response, then:

**Prompt to Codex:**
> Delete worklog [ID].

**Expected (MUST happen before any tool call):**
Codex presents the worklog details (description, duration, date) and asks:
> "Are you sure you want to delete this worklog? (yes/no)"

It must NOT call `delete_worklog` until you reply "yes".

**Reply:** `no`

**Expected:** Codex confirms deletion was cancelled. No worklog deleted.

---

## Test 5 — Reconcile with Overlap Protection

**Setup:** Ensure there is at least one existing worklog for today (from Test 3).

**Prompt to Codex:**
> Reconcile my worklogs. I worked on backend bug fixing from 9am to 11am today.

**If the proposed time overlaps an existing entry, expected:**
Codex presents both the existing entry and the proposed new one, then asks:
> "Entry A already covers part of this time. Keep existing / replace existing / split?"

It must NOT auto-create the conflicting entry.

**Reply:** `keep existing`

**Expected:** Codex skips the conflicting portion and only creates a non-overlapping entry (or confirms no action taken).

---

## Test 6 — Session Bookending (activity log)

This test must be run via `codex/bin/kadle-codex`, not plain `codex`.

**Steps:**
1. Run: `./codex/bin/kadle-codex` (from the kadlekai project root)
2. Ask anything: "What's my timer status?"
3. Exit Codex (Ctrl+D or type `exit`)

**Expected on exit:**
- Terminal prints: "Session ended. Open Codex and say 'reconcile my worklogs' to log this session."
- File `~/.kadlekai/activity.jsonl` contains a `SessionStart` and `SessionEnd` JSON line for this session
- File `~/.codex/kadle/state.json` contains `last_session_end` and `last_project`

**Verification:**
```bash
tail -2 ~/.kadlekai/activity.jsonl
cat ~/.codex/kadle/state.json
```

---

## Test 7 — Fresh Install via install.sh

Run in a temp shell with no existing skill installed:

```bash
# Backup existing skill if present
mv ~/.codex/skills/kadlekai-time-tracking ~/.codex/skills/kadlekai-time-tracking.bak 2>/dev/null || true

# Run installer
curl -fsSL https://raw.githubusercontent.com/anandhak/kadlekai-codex-skill/main/install.sh | bash

# Verify
ls ~/.codex/skills/kadlekai-time-tracking/SKILL.md
ls ~/.codex/kadle/mcp/dist/index.js
```

**Expected:** Both files exist. Installer prints post-install instructions including token generation snippet and API URL defaulting to `https://kadle.beskar.tech`.

```bash
# Restore backup
mv ~/.codex/skills/kadlekai-time-tracking.bak ~/.codex/skills/kadlekai-time-tracking 2>/dev/null || true
```

---

## Summary

| Test | Description | Result |
|---|---|---|
| 1 | Timer status check | |
| 2 | Generate report (no crash) | |
| 3 | Start + stop timer | |
| 4 | Delete confirmation prompt | |
| 5 | Overlap protection during reconcile | |
| 6 | Session bookending (activity.jsonl) | |
| 7 | Fresh install via install.sh | |
