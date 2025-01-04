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

# Version check functions
get_vim_version() {
  nvim --version | grep "NVIM v" --color=never || echo "not installed"
}

get_vscode_version() {
  code --version | head -n1 || echo "not installed"
}

get_chrome_version() {
  google-chrome --version || echo "not installed"
}

get_cursor_version() {
  local cursor_path="$HOME/bin/cursor"
  if [ -f "$cursor_path" ]; then
    md5sum "$cursor_path" | cut -d' ' -f1
  else
    echo "not installed"
  fi
}

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🚀 Starting quick update process..."
echo "-----------------------------------"

# Track success/failure and versions
declare -A before_versions
declare -A after_versions
declare -a failed_updates=()

# Get initial versions
echo "📊 Checking current versions..."
before_versions["update_vim.sh"]=$(get_vim_version)
before_versions["update_code.sh"]=$(get_vscode_version)
before_versions["update_chrome.sh"]=$(get_chrome_version)
before_versions["update_cursor.sh"]=$(get_cursor_version)

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

# Get final versions
after_versions["update_vim.sh"]=$(get_vim_version)
after_versions["update_code.sh"]=$(get_vscode_version)
after_versions["update_chrome.sh"]=$(get_chrome_version)
after_versions["update_cursor.sh"]=$(get_cursor_version)

echo -e "\n-----------------------------------"
echo "📋 Update Summary:"
echo "Total scripts: ${#UPDATE_SCRIPTS[@]}"
echo "Failed scripts: ${#failed_updates[@]}"

echo -e "\n📊 Version Changes:"
for script in "${UPDATE_SCRIPTS[@]}"; do
  app_name=${script#update_} # Remove 'update_' prefix
  app_name=${app_name%.sh}   # Remove '.sh' suffix
  echo "- ${app_name^}:"     # Capitalize first letter
  echo "  Before: ${before_versions[$script]}"
  echo "  After:  ${after_versions[$script]}"
done

if [ ${#failed_updates[@]} -gt 0 ]; then
  echo -e "\n❌ Failed updates:"
  printf '%s\n' "${failed_updates[@]}"
  exit 1
else
  echo -e "\n✨ All updates completed successfully!"
fi
