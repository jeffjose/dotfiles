#!/usr/bin/env -S bash --noprofile
#
# Update mise tools

set -euo pipefail

# Force npm to run postinstall scripts and pull platform-native optional deps
# even if ~/.npmrc disables them (e.g. corporate hardening). Without this, mise's
# npm: backend silently produces broken installs of @anthropic-ai/claude-code etc.
export npm_config_ignore_scripts=false
export npm_config_omit=

# Update dotfiles first
echo "Updating dotfiles..."
cd ~/dotfiles
git pull
./setup
cd - > /dev/null

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

# Function to check if pnpm shim exists and is valid
check_pnpm_shim() {
  local shim_path="$HOME/.local/share/mise/shims/pnpm"
  # Check if it's a symbolic link and it points to an existing file
  [ -L "$shim_path" ] && [ -e "$shim_path" ]
}

# Try to fix pnpm shim up to 5 times if needed
shim_fixed=false
for i in {1..5}; do
  if check_pnpm_shim; then
    echo "pnpm shim is valid."
    shim_fixed=true
    break
  fi

  echo "Attempt $i of 5: pnpm shim is invalid or missing. Trying to fix..."
  rm -rf "$HOME/.local/share/mise/shims"
  "$MISE_BINARY" reshim
  "$MISE_BINARY" install
  "$MISE_BINARY" reshim
  sleep 1 # Give it a moment to settle
done

if ! $shim_fixed; then
  echo "Failed to fix pnpm shim after 5 attempts." >&2
  exit 1
fi

# Self-heal claude-code if its native binary is missing (see script header).
"$HOME/dotfiles/scripts/install/fix-mise-claude-code.sh"

exit 0
