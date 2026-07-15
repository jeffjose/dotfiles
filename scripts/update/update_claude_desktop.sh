#!/usr/bin/env bash
#
# Install / update Claude Desktop as a managed AppImage via scripts/utils/appimage.sh.
#
# Claude Desktop used to have its own bespoke installer (curl + GitHub API + arch
# detection + version tag file + a corp-host guard, all hand-rolled). It's now
# managed like every other AppImage (code, antigravity, ghostty, ...). The one
# special requirement — never auto-install on a Google corp host — lives in the
# reusable `personal-only` guard (scripts/utils/appimage-guards/personal-only.sh),
# wired up via the catalog (scripts/utils/appimage-catalog.tsv).
#
# The community Linux build comes from aaddrick/claude-desktop-debian (Anthropic
# ships no official Linux app). On a fresh personal machine this installs;
# afterwards `uq`'s update_appimage.sh keeps it current via `appimage update --all`
# (which re-runs the guard), so re-running this is a fast no-op.
#
# Jeffrey Jose | 2026-07-15
#
set -e # Exit on error

APPIMAGE="$HOME/dotfiles/scripts/utils/appimage.sh"
NAME="claude-desktop"
META="$HOME/bin/.appimage/meta/$NAME.json"

if [ ! -x "$APPIMAGE" ]; then
  echo "⚠️  appimage manager not found at $APPIMAGE"
  exit 1
fi

echo "🔄 Checking for Claude Desktop updates..."

if [ -f "$META" ]; then
  # Already managed — check the source and upgrade only if newer. The guard
  # recorded in metadata runs automatically before any reinstall.
  "$APPIMAGE" update "$NAME"
else
  # First install: resolve from the catalog (source URL + personal-only guard).
  echo "📥 Installing Claude Desktop AppImage..."
  "$APPIMAGE" install "$NAME"
fi

# Retire the legacy bespoke install artifact once the managed install has taken
# over (the old ~/bin/claude-desktop binary is replaced by a wrapper by appimage).
if [ -f "$META" ] && [ -f "$HOME/bin/.claude-desktop.tag" ]; then
  rm -f "$HOME/bin/.claude-desktop.tag"
fi

echo "✅ Claude Desktop update complete!"
