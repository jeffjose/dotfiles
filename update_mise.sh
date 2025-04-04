#!/usr/bin/env -S bash --noprofile
#
# Update mise tools

echo "Updating mise..."
mise self-update --yes

echo "Upgrading mise tools..."
mise upgrade --bump

which mise

# Function to check if pnpm shim exists and is valid
check_pnpm_shim() {
  local shim_path="/home/jeffjose/.local/share/mise/shims/pnpm"
  if [ ! -L "$shim_path" ] || [ ! -e "$shim_path" ]; then
    return 1
  fi
  return 0
}

# Try reshim process up to 3 times if needed
for i in {1..3}; do
  if ! check_pnpm_shim; then
    echo "Attempt $i: pnpm shim is invalid or missing, running reshim process..."
    rm -rf /home/jeffjose/.local/share/mise/shims
    mise reshim
    mise install
    mise reshim
  else
    echo "pnpm shim is valid, no need for reshim"
    break
  fi
done

exit 0
