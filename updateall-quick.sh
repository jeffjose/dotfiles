#!/bin/bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
SCRIPTS_DIR="$HOME/dotfiles"
UPDATE_SCRIPTS=(
  "update_vim.sh"
  "update_code.sh"
  "update_chrome.sh"
  "update_cursor.sh"
  #"update_rust.sh"  # Currently disabled
)

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🚀 Starting quick update process..."
echo "-----------------------------------"

# Track success/failure
declare -a failed_updates=()

# Run each update script
for script in "${UPDATE_SCRIPTS[@]}"; do
  echo -e "\n📦 Running $script..."
  if [ -x "$SCRIPTS_DIR/$script" ]; then
    if "$SCRIPTS_DIR/$script"; then
      echo "✅ $script completed successfully"
    else
      echo "❌ $script failed"
      failed_updates+=("$script")
    fi
  else
    echo "⚠️  Warning: $script not found or not executable"
    failed_updates+=("$script")
  fi
done

echo -e "\n-----------------------------------"
echo "📋 Update Summary:"
echo "Total scripts: ${#UPDATE_SCRIPTS[@]}"
echo "Failed scripts: ${#failed_updates[@]}"

if [ ${#failed_updates[@]} -gt 0 ]; then
  echo -e "\n❌ Failed updates:"
  printf '%s\n' "${failed_updates[@]}"
  exit 1
else
  echo -e "\n✨ All updates completed successfully!"
fi
