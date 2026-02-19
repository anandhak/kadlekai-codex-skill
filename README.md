# Kadlekai Time Tracking — Codex Skill

A [Codex](https://github.com/openai/codex) skill that lets you track time in [Kadlekai](https://kadle.ai) directly from your coding sessions — start/stop timers, log work, reconcile sessions into worklogs, and query time reports.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/beskar-labs/kadlekai-codex-skill/main/install.sh | bash
```

Or install manually:

```bash
mkdir -p ~/.codex/skills/kadlekai-time-tracking
curl -fsSL https://raw.githubusercontent.com/beskar-labs/kadlekai-codex-skill/main/kadlekai-time-tracking/SKILL.md \
  -o ~/.codex/skills/kadlekai-time-tracking/SKILL.md
```

## Token Generation

Generate an API token from the Kadlekai Rails app:

```bash
bin/rails runner "
user = User.find_by(email: 'your@email.com')
auth_service = AuthenticationService.new(current_user: user, request: nil)
result = auth_service.create_api_key_for_user(user, client_name: 'Codex', expiry_hours: 720)
puts 'Token: ' + result[:auth_token]
"
```

## MCP Configuration

Add to `~/.codex/config.toml`:

```toml
[mcp_servers.kadlekai]
command = "node"
args = ["/path/to/kadlekai/mcp-server/dist/index.js"]

[mcp_servers.kadlekai.env]
KADLEKAI_API_TOKEN = "your_token_here"
KADLEKAI_API_URL = "https://kadle.ai"
```

## Available Commands

| Say | What happens |
|---|---|
| "start timer [description]" | Starts a new timer (warns if one is running) |
| "stop timer" | Stops the running timer |
| "log X hours [description]" | Creates a completed worklog entry |
| "timer status" | Shows elapsed time and current description |
| "report today / this week / this month" | Generates a time summary |
| "reconcile my worklogs" | Walks through session work and logs it |
| "update worklog [id]" | Edits an existing worklog |
| "delete worklog [id]" | Asks for confirmation, then deletes |

## Reconciliation

Say **"reconcile my worklogs"** or **"log today's work"** at the end of a session. Codex will:

1. Ask what you worked on and for how long
2. Check existing entries for the day
3. Match your work to a project
4. Confirm the entry before creating it

## Safety Rules

- **Delete confirmation**: Codex always shows worklog details and asks "Are you sure?" before deleting
- **Overlap protection**: If a proposed entry overlaps an existing worklog, Codex stops and asks what to do

## MCP Server Version

This skill uses the Kadlekai MCP server. The installer downloads the latest version from S3. The source is in the [kadlekai](https://gitlab.beskar.tech/beskar/kadlekai) repo under `mcp-server/`.
