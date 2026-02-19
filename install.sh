#!/usr/bin/env bash
# Kadlekai Time Tracking — Codex Skill Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/beskar-labs/kadlekai-codex-skill/main/install.sh | bash
set -euo pipefail

SKILL_DIR="${HOME}/.codex/skills/kadlekai-time-tracking"
CODEX_CONFIG="${HOME}/.codex/config.toml"
MCP_DIR="${HOME}/.codex/kadle/mcp"
MCP_S3_URL="https://beskar-kadlekai-mcp.s3.amazonaws.com/packages/kadlekai-mcp-latest.tgz"
SKILL_RAW_URL="https://raw.githubusercontent.com/beskar-labs/kadlekai-codex-skill/main/kadlekai-time-tracking/SKILL.md"

echo "==> Installing Kadlekai Time Tracking skill for Codex..."

# 1. Install SKILL.md
echo "    Downloading skill definition..."
mkdir -p "${SKILL_DIR}"
curl -fsSL "${SKILL_RAW_URL}" -o "${SKILL_DIR}/SKILL.md"
echo "    ✓ Skill installed at ${SKILL_DIR}/SKILL.md"

# 2. Append MCP config block (idempotent)
if [[ -f "${CODEX_CONFIG}" ]] && grep -q '\[mcp_servers\.kadlekai\]' "${CODEX_CONFIG}" 2>/dev/null; then
  echo "    ✓ MCP config already present in ${CODEX_CONFIG} — skipping"
else
  echo "    Adding MCP server config to ${CODEX_CONFIG}..."
  mkdir -p "$(dirname "${CODEX_CONFIG}")"
  cat >> "${CODEX_CONFIG}" <<'EOF'

[mcp_servers.kadlekai]
command = "node"
args = ["${HOME}/.codex/kadle/mcp/dist/index.js"]

[mcp_servers.kadlekai.env]
KADLEKAI_API_TOKEN = ""
KADLEKAI_API_URL = "https://kadle.ai"
EOF
  echo "    ✓ MCP config added"
fi

# 3. Download and extract MCP server
echo "    Downloading MCP server..."
mkdir -p "${MCP_DIR}"
TMP_TGZ="$(mktemp /tmp/kadlekai-mcp-XXXXXX.tgz)"
curl -fsSL "${MCP_S3_URL}" -o "${TMP_TGZ}"
tar -xzf "${TMP_TGZ}" -C "${MCP_DIR}" --strip-components=1
rm -f "${TMP_TGZ}"
echo "    ✓ MCP server extracted to ${MCP_DIR}"

# 4. Post-install instructions
echo ""
echo "============================================================"
echo "  Kadlekai Time Tracking skill installed!"
echo "============================================================"
echo ""
echo "Next steps:"
echo ""
echo "  1. Generate an API token from your Kadlekai Rails app:"
echo ""
echo "     bin/rails runner \""
echo "     user = User.find_by(email: 'your@email.com')"
echo "     auth_service = AuthenticationService.new(current_user: user, request: nil)"
echo "     result = auth_service.create_api_key_for_user(user, client_name: 'Codex', expiry_hours: 720)"
echo "     puts 'Token: ' + result[:auth_token]"
echo "     \""
echo ""
echo "  2. Set your environment variables:"
echo ""
echo "     export KADLEKAI_API_TOKEN=your_token_here"
echo "     export KADLEKAI_API_URL=https://kadle.ai"
echo ""
echo "  3. Edit ${CODEX_CONFIG} and fill in KADLEKAI_API_TOKEN."
echo ""
echo "  4. Start a Codex session and say: 'reconcile my worklogs'"
echo ""
