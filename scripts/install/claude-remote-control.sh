#!/bin/bash
#
# Jeffrey Jose | Jun 6, 2026
#
# Install + start the Claude Code Remote Control systemd user service.
# Idempotent: safe to re-run. Handles the interactive bits (login, trust)
# so a fresh machine goes from clone -> running with one command.

set -euo pipefail

echo "-----------------"
echo "Claude Remote Control"
echo "-----------------"

# Resolve this repo's service file relative to this script's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_SRC="$SCRIPT_DIR/../../services/claude-remote-control.service"
SERVICE_DST="$HOME/.config/systemd/user/claude-remote-control.service"
UNIT="claude-remote-control.service"

[ -f "$SERVICE_SRC" ] || { echo "ERROR: $SERVICE_SRC not found"; exit 1; }

# 1. Locate the claude binary (mise shim first, then PATH).
CLAUDE="$HOME/.local/share/mise/shims/claude"
[ -x "$CLAUDE" ] || CLAUDE="$(command -v claude || true)"
if [ -z "$CLAUDE" ]; then
  echo "ERROR: 'claude' not found. Install Claude Code first."
  exit 1
fi
echo "claude: $CLAUDE"

# 2. Ensure logged in (needs a Claude subscription; OAuth, not just an API key).
if "$CLAUDE" auth status 2>/dev/null | jq -e '.loggedIn == true' >/dev/null 2>&1; then
  echo "auth: already logged in"
else
  echo "auth: not logged in -> launching interactive login..."
  "$CLAUDE" auth login
fi

# 3. Trust $HOME (equivalent to accepting the workspace-trust dialog; required headless).
CFG="$HOME/.claude.json"
[ -f "$CFG" ] || echo '{}' > "$CFG"
tmp="$(mktemp)"
jq --arg h "$HOME" '.projects[$h].hasTrustDialogAccepted = true' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
echo "trust: $HOME marked trusted"

# 4. Symlink the unit into the user systemd dir.
mkdir -p "$(dirname "$SERVICE_DST")"
ln -sf "$SERVICE_SRC" "$SERVICE_DST"
echo "unit:  $SERVICE_DST -> $SERVICE_SRC"

# 5. Linger so it starts at boot and survives logout.
loginctl enable-linger "$USER"
echo "linger: enabled for $USER"

# 6. Reload, enable, (re)start.
systemctl --user daemon-reload
systemctl --user enable --now "$UNIT"
systemctl --user restart "$UNIT"

echo
systemctl --user --no-pager status "$UNIT" | sed -n '1,4p'
echo
echo "Done. Connect from the Claude mobile app or https://claude.ai/code"
echo "Logs:  journalctl --user -u $UNIT -f"
