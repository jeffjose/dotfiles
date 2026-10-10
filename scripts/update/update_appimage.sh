#!/usr/bin/env bash
#
# Update all AppImages managed by scripts/utils/appimage.sh
# (ghostty, antigravity, claude-desktop, dp-code, ...).
#
# Jeffrey Jose | 2026-07-14
#
set -e # Exit on error

APPIMAGE="$HOME/dotfiles/scripts/utils/appimage.sh"

source "$HOME/dotfiles/scripts/lib/ui.sh"

if [ ! -x "$APPIMAGE" ]; then
  err "appimage manager not found at $APPIMAGE"
  exit 1
fi

"$APPIMAGE" update --all
