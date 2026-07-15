#!/usr/bin/env bash
#
# Install / update VS Code as an AppImage via scripts/utils/appimage.sh.
#
# VS Code used to be installed from Microsoft's .deb (dpkg -Ei). We now favour
# AppImages, so `code` is managed like every other AppImage (ghostty, antigravity,
# claude-desktop, ...). Microsoft ships no official AppImage — issue microsoft/vscode#10857
# has been open for years — so we use valicm/VSCode-AppImage, which repackages the
# *official* VS Code release binary into an AppImage (not the de-branded VSCodium fork).
#
# On a fresh machine this installs; afterwards `uq`'s update_appimage.sh keeps it
# current via `appimage update --all`, so re-running this is a fast no-op.
#
# Migrating off the .deb: after the AppImage installs, remove the old system
# package once with `sudo dpkg -P code` (the ~/bin/code wrapper shadows /usr/bin/code
# in PATH, so this is safe to do at your leisure).
#
# Jeffrey Jose | 2026-07-15
#
set -e # Exit on error

APPIMAGE="$HOME/dotfiles/scripts/utils/appimage.sh"
SOURCE_URL="https://github.com/valicm/VSCode-AppImage"
NAME="code"
META="$HOME/bin/.appimage/meta/$NAME.json"

if [ ! -x "$APPIMAGE" ]; then
  echo "⚠️  appimage manager not found at $APPIMAGE"
  exit 1
fi

echo "🔄 Checking for VS Code updates..."

# Current version. The AppImage's `code` entrypoint is the GUI Electron binary,
# which ignores `--version` (the real CLI lives at usr/bin/bin/code inside the
# image), so read the version the manager recorded in metadata instead.
echo -n "Current version: "
jq -r '.release_name // .tag // "-"' "$META" 2>/dev/null || echo "not installed"

if [ -f "$META" ]; then
  # Already managed — check the source and upgrade only if newer.
  "$APPIMAGE" update "$NAME"
else
  # First install: repackaged official VS Code AppImage. --name pins the wrapper
  # to `code` (the derived name from the asset filename would be "vscode-x86").
  echo "📥 Installing VS Code AppImage..."
  "$APPIMAGE" install --name "$NAME" "$SOURCE_URL"
  echo "ℹ️  If the old .deb is still installed, remove it once: sudo dpkg -P code"
fi

echo "✅ VS Code update complete!"
