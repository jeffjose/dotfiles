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

# Personal-machine detection. Be defensive — check multiple sources and
# fail-closed (treat as corp) on any signal of a Google host.
is_corp_host() {
  local fqdn shortname domain

  fqdn=$(hostname -f 2>/dev/null || true)
  [ -z "$fqdn" ] && fqdn=$(hostname --fqdn 2>/dev/null || true)
  [ -z "$fqdn" ] && fqdn=$(hostname 2>/dev/null || true)
  shortname=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
  domain=$(hostname -d 2>/dev/null || true)

  fqdn=$(echo "$fqdn" | tr '[:upper:]' '[:lower:]')
  domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
  shortname=$(echo "$shortname" | tr '[:upper:]' '[:lower:]')

  case "$fqdn" in
    *.google.com|*.corp.google.com|*.c.googlers.com) return 0 ;;
  esac
  case "$domain" in
    google.com|corp.google.com|c.googlers.com) return 0 ;;
  esac

  # Belt and suspenders: glinux-only markers.
  if [ -f /etc/lsb-release ] && grep -qi 'glinux\|goobuntu' /etc/lsb-release 2>/dev/null; then
    return 0
  fi
  if [ -d /google ] || [ -d /usr/local/google ]; then
    return 0
  fi

  return 1
}

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
  echo "🏢 [$NAME] Google corp host detected — should NOT be installed here." >&2
  if confirm "Override and install $NAME anyway?" "n"; then
    echo "⚠️  [$NAME] proceeding on corp host (user override)." >&2
    exit 0
  fi
  exit 1
else
  echo "🏠 [$NAME] personal host detected — safe to install." >&2
  if confirm "Proceed with install/update of $NAME?" "y"; then
    exit 0
  fi
  exit 1
fi
