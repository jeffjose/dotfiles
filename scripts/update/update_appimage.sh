#!/usr/bin/env bash
#
# Update all AppImages managed by scripts/utils/appimage.sh
# (ghostty, antigravity, claude-desktop, dp-code, ...).
#
# Jeffrey Jose | 2026-07-14
#
set -e # Exit on error

APPIMAGE="$HOME/dotfiles/scripts/utils/appimage.sh"

if [ ! -x "$APPIMAGE" ]; then
  echo "⚠️  appimage manager not found at $APPIMAGE"
  exit 1
fi

echo "🔄 Updating managed AppImages..."
"$APPIMAGE" update --all
echo "✅ AppImage update check complete!"
