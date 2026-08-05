#!/bin/bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
SCRIPTS_DIR="$HOME/dotfiles/scripts/update"
UPDATE_SCRIPTS=(
  "update_code.sh"
  "update_chrome.sh"
  #"update_cursor.sh"
  "update_mise.sh"
  "update_deb.sh"
  "update_claude_desktop.sh"
  "update_appimage.sh"
  #"update_rust.sh"  # Currently disabled
)

# Color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Version check functions
declare -A VERSION_COMMANDS=(
  ["update_code.sh"]="jq -r '.release_name // .tag // \"-\"' \$HOME/bin/.appimage/meta/code.json 2>/dev/null || echo 'n/a'"
  ["update_chrome.sh"]="google-chrome --version"
  ["update_cursor.sh"]="md5sum \$HOME/bin/cursor | cut -d' ' -f1"
  ["update_mise.sh"]="mise --version"
  ["update_deb.sh"]="deb_versions"
  ["update_claude_desktop.sh"]="jq -r '.tag // .release_name // \"-\"' \$HOME/bin/.appimage/meta/claude-desktop.json 2>/dev/null || echo 'not installed'"
  ["update_appimage.sh"]="jq -r '.release_name // .tag // \"-\"' \$HOME/bin/.appimage/meta/antigravity.json 2>/dev/null || echo 'n/a'"
)

# update_deb.sh installs whatever misc/package.toml lists, so there is no single
# version to report — ask dpkg for each package instead. Read the names from the
# toml rather than hardcoding them so the summary tracks the config.
deb_versions() {
  local toml="$HOME/dotfiles/misc/package.toml"
  [[ -f "$toml" ]] || { echo "n/a"; return 0; }

  local pkg ver out=""
  while read -r pkg; do
    [[ -n "$pkg" ]] || continue
    ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null) || ver=""
    out="${out:+$out, }${pkg}=${ver:--}"
  done < <(sed -nE 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$toml")

  echo "${out:-n/a}"
}

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

# Prompt for the sudo password up front and keep the credential warm.
#
# Asking first thing means the prompt is on screen before you wander off to
# another terminal, instead of appearing a second later behind the dotfiles
# pull. The background loop then refreshes the timestamp so none of the update
# scripts re-prompt part way through a long run.
SUDO_KEEPALIVE_PID=""

stop_sudo_keepalive() {
  [[ -n "$SUDO_KEEPALIVE_PID" ]] || return 0

  # Note the loop's in-flight `sleep` before killing the loop itself: killing a
  # subshell doesn't kill its children, so the sleep would otherwise hang around
  # orphaned for up to a minute after the script exits.
  local children
  children="$(pgrep -P "$SUDO_KEEPALIVE_PID" 2>/dev/null || true)"
  kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  if [[ -n "$children" ]]; then
    kill $children 2>/dev/null || true
  fi
  SUDO_KEEPALIVE_PID=""
}

# Best-effort, never fatal. `sudo -v` is not portable across machines:
#
#   - work/managed hosts often grant sudo for a fixed list of commands only, so
#     validating the credential on its own is refused outright ("may not run
#     sudo");
#   - some require a security-key touch or re-auth per invocation, which makes a
#     cached timestamp meaningless;
#   - a host may have passwordless sudo, or no sudo binary at all.
#
# None of that should stop the run — most of what `uq` does (appimages, mise,
# dotfiles) needs no root, and the steps that do will prompt for themselves.
check_sudo() {
  # main() calls this on both sides of the dotfiles pull; only warm up once.
  [[ -z "$SUDO_KEEPALIVE_PID" ]] || return 0

  if ! command -v sudo >/dev/null 2>&1; then
    echo "ℹ️  No sudo on this host — skipping the credential warm-up."
    return 0
  fi

  # Already usable without a prompt (NOPASSWD sudoers, or a still-warm cache).
  # Nothing to ask for, and nothing worth keeping alive.
  if sudo -n true 2>/dev/null; then
    return 0
  fi

  echo "🔑 Asking for sudo up front so the rest of the run is unattended..."
  if ! sudo -v; then
    echo "⚠️  Couldn't pre-authorise sudo — continuing anyway." >&2
    echo "    Steps that need root will prompt when they get there." >&2
    return 0
  fi

  # Only worth a keepalive if the credential actually caches. Where it doesn't
  # (touch-per-command setups), `sudo -v` succeeds but leaves nothing behind, so
  # the loop would just churn — skip it.
  if ! sudo -n true 2>/dev/null; then
    echo "ℹ️  sudo doesn't cache credentials here; skipping the refresh loop."
    return 0
  fi

  # Refresh every minute (the default timeout is 5) until the script exits.
  while true; do
    sleep 60
    kill -0 "$$" 2>/dev/null || exit 0
    sudo -n true 2>/dev/null || exit 0
  done &
  SUDO_KEEPALIVE_PID=$!
  trap stop_sudo_keepalive EXIT
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

  check_sudo

  # Update dotfiles first (best-effort — don't abort the whole update run if the
  # pull fails, e.g. offline, merge conflict, or detached HEAD). Subshell keeps a
  # failed cd/pull from stranding us in the wrong directory.
  echo "📂 Updating dotfiles..."
  if ( cd ~/dotfiles && git pull && ./setup ); then
    echo "✅ Dotfiles updated"
  else
    echo "⚠️  Dotfiles update failed; continuing with the rest of the updates." >&2
  fi

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
