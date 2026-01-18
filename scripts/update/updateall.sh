#!/bin/bash
#
# Jeffrey Jose | Jan 10, 2016
#
set -e # Exit on error

# Constants
SCRIPTS_DIR="$HOME/dotfiles/scripts/update"
UPDATE_SCRIPTS=(
  "update_rust.sh"
  "update_vim.sh"
  "update_code.sh"
  "update_chrome.sh"
  "update_cursor.sh"
)

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🚀 Starting full system update..."
echo "-----------------------------------"

# Track failures
declare -a failed_tasks=()

# Function to run a command and track its success/failure
run_task() {
  local task_name="$1"
  shift
  echo -e "\n📦 $task_name..."
  if "$@"; then
    echo "✅ $task_name completed successfully"
    return 0
  else
    echo "❌ $task_name failed"
    failed_tasks+=("$task_name")
    return 1
  fi
}

# Update apt packages
echo -e "\n🔄 System Package Updates"
echo "-----------------------------------"
run_task "APT autoclean" sudo apt -y autoclean
run_task "APT clean" sudo apt -y clean
run_task "APT update" sudo apt -y update
run_task "APT upgrade" sudo apt -y upgrade
run_task "APT autoremove" sudo apt -y autoremove

# Update node packages
echo -e "\n🔄 Node Package Updates"
echo "-----------------------------------"
run_task "Yarn global upgrade" yarn global upgrade all

# Update apps
echo -e "\n🔄 Application Updates"
echo "-----------------------------------"

# Run each update script
for script in "${UPDATE_SCRIPTS[@]}"; do
  if [ -x "$SCRIPTS_DIR/$script" ]; then
    run_task "$script" "$SCRIPTS_DIR/$script"
  else
    echo "⚠️  Warning: $script not found or not executable"
    failed_tasks+=("$script")
  fi
done

# Optional updates (commented out)
#echo -e "\n🔄 Optional Updates"
#echo "-----------------------------------"
#run_task "Flutter upgrade" flutter upgrade --force
#run_task "Go packages" go get -u all

echo -e "\n-----------------------------------"
echo "📋 Update Summary:"
echo "Status:"
echo "  - System packages ✓"
echo "  - Node packages ✓"
echo "  - Applications ✓"

if [ ${#failed_tasks[@]} -gt 0 ]; then
  echo -e "\n❌ Failed tasks:"
  printf '%s\n' "${failed_tasks[@]}"
  exit 1
else
  echo -e "\n✨ All updates completed successfully!"
fi
