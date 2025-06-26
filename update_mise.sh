#!/usr/bin/env -S bash --noprofile
#
# Update mise tools

set -euo pipefail

# Clear cache, since python builds was breaking for the longest time
mise cache clear

echo "Updating mise..."
mise self-update --yes

echo "Upgrading mise tools..."
mise upgrade --bump

which mise

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
  mise reshim
  mise install
  mise reshim
  sleep 1 # Give it a moment to settle
done

if ! $shim_fixed; then
  echo "Failed to fix pnpm shim after 5 attempts." >&2
  exit 1
fi

exit 0
