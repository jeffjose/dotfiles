#!/usr/bin/env bash
#
# appimage guard: personal-only
#
# Allow install/update ONLY on personal (non-corp) hosts. On a Google corp host
# the default is to skip, but the user can override interactively.
#
# Guard contract (see scripts/utils/appimage.sh):
#   - exit 0  => proceed with install/update
#   - exit !0 => skip this app
#   - context arrives via env: APPIMAGE_NAME, APPIMAGE_ACTION,
#     APPIMAGE_CUR_VERSION, APPIMAGE_NEW_VERSION
#   - may prompt the user on /dev/tty
#
# Jeffrey Jose | 2026-07-15

set -euo pipefail

NAME="${APPIMAGE_NAME:-this app}"

source "$HOME/dotfiles/scripts/lib/ui.sh"

# Personal-machine detection (is_corp_host) is shared with uq and ./setup.
source "$HOME/dotfiles/scripts/lib/host.sh"

# Interactive confirm with a smart default and a 10s timeout. Non-interactive
# runs fall back to the default.
confirm() {
  local prompt="$1" default="$2" reply hint timeout=10
  if [ "$default" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  # Non-interactive (no usable controlling terminal): fall back to the default.
  # Test that /dev/tty can actually be opened, not just that the node exists.
  if ! { true </dev/tty; } 2>/dev/null; then
    echo "$prompt $hint (non-interactive, using default: $default)" >&2
    [ "$default" = "y" ]
    return $?
  fi
  if ! read -r -t "$timeout" -p "$prompt $hint (${timeout}s → $default) " reply </dev/tty 2>/dev/null; then
    reply=""
    echo "" >&2
  fi
  reply=${reply:-$default}
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

if is_corp_host; then
  warn "$NAME: Google corp host detected — should NOT be installed here"
  if confirm "Override and install $NAME anyway?" "n"; then
    warn "$NAME: proceeding on corp host (user override)"
    exit 0
  fi
  exit 1
else
  say "$CYAN" "Guard" "$NAME: personal host detected — safe to install" >&2
  if confirm "Proceed with install/update of $NAME?" "y"; then
    exit 0
  fi
  exit 1
fi
