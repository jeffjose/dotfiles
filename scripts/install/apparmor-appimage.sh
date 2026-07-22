#!/usr/bin/env bash
#
# Install the AppArmor profiles our Electron AppImages need.
#
# See apps/apparmor/code-appimage for the full explanation. Short version:
# Ubuntu 24.04+ blocks CAP_SYS_ADMIN inside unprivileged user namespaces, which
# breaks Chromium's namespace sandbox, which makes Electron fall back to the
# setuid sandbox, which cannot work from a squashfs AppImage. Naming the binary
# in a profile that grants `userns` fixes it while keeping the app sandboxed.
#
# Idempotent: does nothing when the installed profile already matches, so `uq`
# can call this on every run. Needs sudo (writes /etc/apparmor.d and reloads).
#
# Jeffrey Jose | 2026-07-22
#
set -euo pipefail

# Usage: apparmor-appimage.sh [profile ...]
#   no args  -> install every profile in apps/apparmor (what `uq` does)
#   with args -> only those, silently skipping ones we ship no profile for.
#               appimage.sh calls it this way after writing a wrapper, so an
#               app with no profile costs nothing.
SRC_DIR="$HOME/dotfiles/apps/apparmor"
DEST_DIR="/etc/apparmor.d"

if [ "$#" -gt 0 ]; then
  PROFILES=()
  for arg in "$@"; do
    [ -f "$SRC_DIR/$arg" ] && PROFILES+=("$arg")
  done
  [ ${#PROFILES[@]} -eq 0 ] && exit 0
else
  mapfile -t PROFILES < <(cd "$SRC_DIR" 2>/dev/null && ls 2>/dev/null || true)
  [ ${#PROFILES[@]} -eq 0 ] && { echo "No AppArmor profiles to install."; exit 0; }
fi

# No AppArmor (non-Ubuntu, container, BSD) -> nothing to do.
if [ ! -d "$DEST_DIR" ] || ! command -v apparmor_parser >/dev/null 2>&1; then
  echo "AppArmor not present; skipping profile install."
  exit 0
fi

# The restriction these profiles work around is off -> they buy nothing.
restricted="$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo 0)"
if [ "$restricted" != "1" ]; then
  echo "kernel.apparmor_restrict_unprivileged_userns=$restricted; profiles not needed."
  exit 0
fi

changed=()
for profile in "${PROFILES[@]}"; do
  src="$SRC_DIR/$profile"
  dest="$DEST_DIR/$profile"

  if [ ! -f "$src" ]; then
    continue
  fi

  if cmp -s "$src" "$dest"; then
    continue
  fi

  echo "📝 Installing AppArmor profile: $profile"
  sudo install -m 0644 -o root -g root "$src" "$dest"
  changed+=("$profile")
done

if [ ${#changed[@]} -eq 0 ]; then
  echo "✓ AppArmor profiles already current"
  exit 0
fi

for profile in "${changed[@]}"; do
  sudo apparmor_parser -r -W "$DEST_DIR/$profile"
done

echo "✓ Loaded ${#changed[@]} AppArmor profile(s): ${changed[*]}"
echo "ℹ️  Restart the app for the new profile to take effect."
