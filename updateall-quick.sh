#!/bin/bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
SCRIPTS_DIR="$HOME/dotfiles"
UPDATE_SCRIPTS=(
  "update_code.sh"
  "update_chrome.sh"
  #"update_cursor.sh"
  "update_mise.sh"
  #"update_rust.sh"  # Currently disabled
)

# Color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Version check functions
declare -A VERSION_COMMANDS=(
  ["update_code.sh"]="code --version | head -n1"
  ["update_chrome.sh"]="google-chrome --version"
  ["update_cursor.sh"]="md5sum \$HOME/bin/cursor | cut -d' ' -f1"
  ["update_mise.sh"]="mise --version"
)

# Get version for a specific application
get_version() {
  local script="$1"
  local command="${VERSION_COMMANDS[$script]}"

  if [[ -z "$command" ]]; then
    echo "Version check not configured"
    return 1
  fi

  # For cursor, check if binary exists first
  if [[ "$script" == "update_cursor.sh" && ! -f "$HOME/bin/cursor" ]]; then
    echo "not installed"
    return 0
  fi

  eval "$command" 2>/dev/null || echo "not installed"
}

# Check sudo privileges
check_sudo() {
  if ! sudo true; then
    echo "Error: This script requires sudo privileges"
    exit 1
  fi
}

# Initialize version tracking
init_version_tracking() {
  declare -gA before_versions
  declare -gA after_versions
  declare -ga failed_updates=()

  echo "📊 Checking current versions..."
  for script in "${UPDATE_SCRIPTS[@]}"; do
    before_versions[$script]=$(get_version "$script")
  done
}

# Run a single update script
run_update_script() {
  local script="$1"
  echo -e "\n📦 Running $script..."

  if [ -x "$SCRIPTS_DIR/$script" ]; then
    if "$SCRIPTS_DIR/$script"; then
      echo "✅ $script completed successfully"
      return 0
    else
      echo "❌ $script failed"
      failed_updates+=("$script")
      return 1
    fi
  else
    echo "⚠️  Warning: $script not found or not executable"
    failed_updates+=("$script")
    return 1
  fi
}

# Get final versions after updates
collect_final_versions() {
  for script in "${UPDATE_SCRIPTS[@]}"; do
    after_versions[$script]=$(get_version "$script")
  done
}

# Print update summary
print_summary() {
  echo -e "\n-----------------------------------"
  echo "📋 Update Summary:"
  echo "Total scripts: ${#UPDATE_SCRIPTS[@]}"
  echo "Failed scripts: ${#failed_updates[@]}"

  echo -e "\n📊 Version Changes:"
  for script in "${UPDATE_SCRIPTS[@]}"; do
    local app_name=${script#update_} # Remove 'update_' prefix
    app_name=${app_name%.sh}        # Remove '.sh' suffix
    echo "- ${app_name^}:"          # Capitalize first letter
    echo "  Before: ${before_versions[$script]}"
    if [ "${before_versions[$script]}" != "${after_versions[$script]}" ]; then
      echo -e "  After:  ${GREEN}${after_versions[$script]}${NC}"
    else
      echo "  After:  ${after_versions[$script]}"
    fi
  done

  if [ ${#failed_updates[@]} -gt 0 ]; then
    echo -e "\n❌ Failed updates:"
    printf '%s\n' "${failed_updates[@]}"
    return 1
  else
    echo -e "\n✨ All updates completed successfully!"
    return 0
  fi
}

# Main execution
main() {
  echo "🚀 Starting quick update process..."
  echo "-----------------------------------"

  # Update dotfiles first
  echo "📂 Updating dotfiles..."
  cd ~/dotfiles
  git pull
  ./setup.sh
  cd - > /dev/null
  echo "✅ Dotfiles updated"

  check_sudo
  init_version_tracking

  # Run updates
  for script in "${UPDATE_SCRIPTS[@]}"; do
    run_update_script "$script" || true  # Continue on error
  done

  collect_final_versions
  print_summary
}

# Run main function
main "$@"
