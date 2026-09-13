#!/usr/bin/env -S bash --noprofile
#
# Update mise tools

set -euo pipefail

# Force npm to run postinstall scripts and pull platform-native optional deps
# even if ~/.npmrc disables them (e.g. corporate hardening). Without this, mise's
# npm: backend silently produces broken installs of @anthropic-ai/claude-code etc.
export npm_config_ignore_scripts=false
export npm_config_omit=

# Update dotfiles first (best-effort — don't abort the mise update if this
# fails, e.g. offline, merge conflict, or detached HEAD). Run in a subshell so
# a failed `cd`/`git pull` can't strand us in the wrong directory.
echo "Updating dotfiles..."
if ! ( cd ~/dotfiles && git pull && ./setup ); then
  echo "⚠️  dotfiles update failed; continuing with mise update." >&2
fi

# Clear caches to prevent corruption from interrupted downloads
mise cache clear
go clean -cache 2>/dev/null || true

echo "Updating mise..."
mise self-update --yes || true

echo "Upgrading mise tools..."
mise upgrade
# mise upgrade --bump  # Commented out to prevent auto-updating config.toml versions

which mise

# Get the actual mise binary location (not the shim)
MISE_BINARY=$(which mise)
if [[ -L "$MISE_BINARY" ]]; then
  # If it's a symlink, follow it to get the real binary
  MISE_BINARY=$(readlink -f "$MISE_BINARY")
fi

# Health-check pnpm by running it, not by stat-ing the shim.
#
# The old check only asserted that ~/.local/share/mise/shims/pnpm was a live
# symlink. That stayed true for weeks while pnpm was entirely unusable: the
# npm:pnpm package ships a shebang-less placeholder that its postinstall swaps
# for the native binary, aube blocks postinstall, and every `pnpm` invocation
# died in node's ESM loader. The shim was fine; what it pointed at was not.
#
# pnpm now comes from aqua (see apps/config.toml), so this failure mode is gone
# -- but a check that cannot observe the failure it exists to catch is worse
# than no check, so it runs the binary.
check_pnpm() {
  pnpm --version >/dev/null 2>&1
}

pnpm_ok=false
for i in {1..5}; do
  if check_pnpm; then
    echo "pnpm is healthy ($(pnpm --version))."
    pnpm_ok=true
    break
  fi

  echo "Attempt $i of 5: pnpm does not run. Trying to fix..."
  rm -rf "$HOME/.local/share/mise/shims"
  "$MISE_BINARY" reshim
  "$MISE_BINARY" install
  "$MISE_BINARY" reshim
  hash -r 2>/dev/null || true
  sleep 1 # Give it a moment to settle
done

if ! $pnpm_ok; then
  echo "pnpm still does not run after 5 attempts." >&2
  exit 1
fi

# Self-heal npm: tools whose aube store under ~/.cache was cleared.
"$HOME/dotfiles/scripts/install/fix-mise-npm-installs.sh"

exit 0
