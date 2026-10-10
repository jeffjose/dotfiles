#!/usr/bin/env -S bash --noprofile
#
# Update mise tools
#
# Usage: update_mise.sh [--filter PATTERN]
#
#   --filter PATTERN  Only upgrade (and prune) tools whose name contains PATTERN
#                     (case-insensitive substring). Skips the dotfiles pull,
#                     mise self-update, cache clears and pnpm health check.
#                     e.g. `update_mise.sh --filter claude` upgrades both
#                     `claude` and `npm:@anthropic-ai/claude-code`.

set -euo pipefail

source "$HOME/dotfiles/scripts/lib/ui.sh"

# Force npm to run postinstall scripts and pull platform-native optional deps
# even if ~/.npmrc disables them (e.g. corporate hardening). Without this, mise's
# npm: backend silently produces broken installs of @anthropic-ai/claude-code etc.
export npm_config_ignore_scripts=false
export npm_config_omit=

MISE_DATA_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}"
MISE_CACHE_DIR="${MISE_CACHE_DIR:-$HOME/.cache/mise}"

# Bytes used by mise's installs + cache, for the before/after report.
mise_disk_usage() {
  du -sb "$MISE_DATA_DIR" "$MISE_CACHE_DIR" 2>/dev/null | awk '{s+=$1} END {printf "%.0f\n", s}'
}

filter=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--filter) filter="${2:?--filter needs a pattern}"; shift 2 ;;
    --filter=*)  filter="${1#*=}"; shift ;;
    -h|--help)   sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) err "unknown argument: $1"; exit 2 ;;
  esac
done

# `mise upgrade` warns twice per branch-pinned tool (the cargo:…jeffjose/* repos
# on branch:main) on every run — "something weird happened with versioning" and
# "upgrading non-version tool requests". Both are expected for a branch ref, so
# drop just those lines from stderr; every other warning still gets through.
mise_upgrade() {
  mise upgrade "$@" 2> >(grep -v -e 'something weird happened with versioning' \
                               -e 'upgrading non-version tool requests' >&2)
}

report_disk_usage() {
  local size_after
  size_after=$(mise_disk_usage)
  say "$GREEN" "Disk" "mise $(numfmt --to=iec "$size_before") → $(numfmt --to=iec "$size_after") \
$DIM(saved $(numfmt --to=iec -- $((size_before - size_after))))$RESET"
}

size_before=$(mise_disk_usage)

if [[ -n "$filter" ]]; then
  mapfile -t tools < <(mise ls --current | awk '{print $1}' | sort -u | grep -iF -- "$filter" || true)
  if [[ ${#tools[@]} -eq 0 ]]; then
    err "no mise tools match '$filter'"
    exit 1
  fi

  say "$CYAN" "Upgrading" "${tools[*]}"
  mise_upgrade "${tools[@]}"
  mise prune --yes "${tools[@]}" || warn "mise prune failed; continuing"

  if printf '%s\n' "${tools[@]}" | grep -q '^npm:'; then
    "$HOME/dotfiles/scripts/install/fix-mise-npm-installs.sh"
  fi

  report_disk_usage
  exit 0
fi

# Update dotfiles first (best-effort — don't abort the mise update if this
# fails, e.g. offline, merge conflict, or detached HEAD). Run in a subshell so
# a failed `cd`/`git pull` can't strand us in the wrong directory.
say "$CYAN" "Updating" "dotfiles"
if ! ( cd ~/dotfiles && git pull && ./setup ); then
  warn "dotfiles update failed; continuing with mise update"
fi

# Clear caches to prevent corruption from interrupted downloads
mise cache clear
go clean -cache 2>/dev/null || true

say "$CYAN" "Updating" "mise itself"
mise self-update --yes || true

say "$CYAN" "Upgrading" "mise tools"
mise_upgrade
# mise upgrade --bump  # Commented out to prevent auto-updating config.toml versions

# `mise upgrade` installs new versions alongside the old ones and never removes
# them, so installs/ grows without bound. Prune every version no tracked config
# still resolves to (mise reinstalls on demand if a project needs one again).
say "$CYAN" "Pruning" "unused tool versions"
mise prune --yes || warn "mise prune failed; continuing"

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
    say "$DIM" "Fresh" "${DIM}pnpm $(pnpm --version) runs$RESET"
    pnpm_ok=true
    break
  fi

  say "$YELLOW" "Repairing" "pnpm does not run (attempt $i of 5)"
  rm -rf "$HOME/.local/share/mise/shims"
  "$MISE_BINARY" reshim
  "$MISE_BINARY" install
  "$MISE_BINARY" reshim
  hash -r 2>/dev/null || true
  sleep 1 # Give it a moment to settle
done

if ! $pnpm_ok; then
  err "pnpm still does not run after 5 attempts"
  exit 1
fi

# Self-heal npm: tools whose aube store under ~/.cache was cleared.
"$HOME/dotfiles/scripts/install/fix-mise-npm-installs.sh"

report_disk_usage

exit 0
