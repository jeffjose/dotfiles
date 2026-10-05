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
# This is the A (AppImage) path. The B (.deb) path is
# scripts/install/install-code-deb.sh — manual, and deliberately not wired into
# `uq`, so nothing reinstalls the .deb behind your back.
#
# Both can be installed side by side. ~/bin/code shadows /usr/bin/code in PATH,
# so a bare `code` runs the AppImage regardless; use /usr/bin/code for the .deb.
# Removing the .deb is therefore optional — not a required migration step.
#
# The wrapper is installed with --inner-cli: the AppImage's entrypoint is the GUI
# Electron binary, which ignores every CLI flag and answers `code --version` or
# `--install-extension` by opening an empty window, so the wrapper mounts the
# image and runs the real CLI inside it instead.
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

# Current version, from the metadata the manager recorded. `code --version`
# would answer too, now that the wrapper runs the CLI bundled inside the image
# (the `inner-cli` flag — the image's own entrypoint is the GUI binary, which
# ignores --version and opens a window instead), but that costs a mount and
# tells us about the installed image rather than what we are about to replace.
echo -n "Current version: "
jq -r '.release_name // .tag // "-"' "$META" 2>/dev/null || echo "not installed"

if [ -f "$META" ]; then
  # Already managed — check the source and upgrade only if newer.
  "$APPIMAGE" update "$NAME"
else
  # First install: repackaged official VS Code AppImage. --name pins the wrapper
  # to `code` (the derived name from the asset filename would be "vscode-x86").
  echo "📥 Installing VS Code AppImage..."
  "$APPIMAGE" install --name "$NAME" --inner-cli "$SOURCE_URL"
  echo "ℹ️  This is the AppImage. For the .deb too: scripts/install/install-code-deb.sh"
fi

# The AppImage needs an AppArmor profile granting `userns`, or Chromium's
# sandbox setup aborts on launch. Idempotent; see the script for why.
"$HOME/dotfiles/scripts/install/apparmor-appimage.sh"

echo "✅ VS Code update complete!"
