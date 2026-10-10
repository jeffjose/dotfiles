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

# On a corp host, keep the tools listed in apps/mise-corp.toml out of every mise
# call below. ./setup links that file into mise's config, which covers mise run
# by hand too — but setup is best-effort in a uq run, and this must not depend
# on it having worked.
source "$HOME/dotfiles/scripts/lib/host.sh"
if is_corp_host; then
  corp_blocked=$(corp_blocked_mise_tools | paste -sd, -)
  if [[ -n "$corp_blocked" ]]; then
    export MISE_DISABLE_TOOLS="$corp_blocked"
    say "$YELLOW" "Corp host" "mise will not install or upgrade: ${corp_blocked//,/, }"
  fi
fi

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

# Rebuild the branch-pinned cargo git tools whose branch has moved.
#
# To mise, "branch:main" is the version, and it is already installed — so
# `mise upgrade` never looks at those repos again and a push to one of them
# reaches no machine. (This is not minimum_release_age: a branch ref has no
# release date, so the quarantine never applies to it.) cargo records the commit
# it built in .crates.toml; compare that to the branch tip and force a reinstall
# when they differ.
#
# A tool that is not installed yet counts as stale too, so this is also what
# installs a newly listed one — which is why it runs ahead of `mise upgrade`.
#
# Each tool mise (re)builds here also loses its copy in ~/.cargo/bin, see
# drop_dev_copy. A tool whose branch has not moved is left alone, dev copy and
# all.
#
# refresh_branch_tools [tool...]: all such tools, or only the ones named.
refresh_branch_tools() {
  local tool path branch url built tip entry
  local -a stale=()
  while IFS=$'\t' read -r tool path branch; do
    if [[ $# -gt 0 ]] && ! printf '%s\n' "$@" | grep -qxF -- "$tool"; then
      continue
    fi
    url=${tool#cargo:}
    built=$(grep -oE '#[0-9a-f]{40}' "$path/.crates.toml" 2>/dev/null | head -n1 | tr -d '#') || true
    tip=$(git ls-remote "$url" "refs/heads/$branch" 2>/dev/null | cut -f1) || true
    if [[ -z "$tip" ]]; then
      warn "could not read $branch of $url; leaving it as is"
    elif [[ "$built" != "$tip" ]]; then
      if [[ -n "$built" ]]; then
        say "$GREEN" "Rebuilding" "${url##*/} ${built:0:7} → ${tip:0:7}"
      else
        say "$GREEN" "Installing" "${url##*/} ${tip:0:7}"
      fi
      stale+=("$tool"$'\t'"$path")
    fi
  done < <(mise ls --current --json 2>/dev/null |
    jq -r 'to_entries[] | .key as $k | .value[]
           | select(($k | startswith("cargo:https://")) and (.version | startswith("branch:")))
           | "\($k)\t\(.install_path)\t\(.version | ltrimstr("branch:"))"' 2>/dev/null || true)

  [[ ${#stale[@]} -gt 0 ]] || return 0
  for entry in "${stale[@]}"; do
    IFS=$'\t' read -r tool path <<<"$entry"
    if mise install --force "$tool"; then
      drop_dev_copy "$path"
    else
      warn "building $tool failed; continuing"
    fi
  done
}

# ~/.cargo/bin sits ahead of the mise shims on PATH, so that a `cargo install
# --path .` of a tool under development wins over the copy mise built from its
# branch. The cost is that the dev copy would go on winning after the work is
# pushed and mise has built something newer. So when mise builds a tool, the
# copy of the same crate in ~/.cargo/bin goes; the next `cargo install --path .`
# puts it back.
#
# drop_dev_copy <mise install path>
drop_dev_copy() {
  local cargo_home="${CARGO_HOME:-$HOME/.cargo}" crate
  while read -r crate; do
    grep -q "^\"$crate " "$cargo_home/.crates.toml" 2>/dev/null || continue
    if cargo uninstall --quiet --root "$cargo_home" "$crate"; then
      say "$YELLOW" "Removed" "dev copy of $crate from $cargo_home/bin — the mise build is newer"
    else
      warn "could not remove the dev copy of $crate from $cargo_home/bin"
    fi
  done < <(sed -nE 's/^"([^ "]+) .*/\1/p' "$1/.crates.toml" 2>/dev/null)
}

# Point rustup's default toolchain at the rust mise resolved.
#
# mise's rust is a numbered rustup toolchain, picked by the RUSTUP_TOOLCHAIN the
# mise shim sets. But ~/.cargo/bin is ahead of the shims on PATH, so a plain
# `cargo` is the rustup proxy and builds with rustup's own default instead —
# "stable", which nothing here updates. That one sits at whatever `rustup
# update` last left on each machine, so the same checkout builds on one box and
# dies with "rustc 1.85.1 is not supported by the following packages" on the
# next. Making mise's toolchain the default leaves one rust, and `mise upgrade`
# already keeps it current.
sync_rustup_default() {
  local want
  command -v rustup >/dev/null 2>&1 || return 0
  want=$(mise current rust 2>/dev/null) || return 0
  [[ -n "$want" ]] || return 0
  [[ "$(rustup default 2>/dev/null)" == "$want-"* ]] && return 0
  if rustup default "$want" >/dev/null 2>&1; then
    say "$GREEN" "Switched" "rustup default to $want, the rust mise manages"
  else
    warn "could not make $want the rustup default; plain \`cargo\` may use an older rust"
  fi
}

report_disk_usage() {
  local size_after
  size_after=$(mise_disk_usage)
  say "$GREEN" "Disk" "mise $(numfmt --to=iec "$size_before") → $(numfmt --to=iec "$size_after") \
$DIM(saved $(numfmt --to=iec -- $((size_before - size_after))))$RESET"
}

size_before=$(mise_disk_usage)

# One tool that will not build must not take the rest of the run with it: the
# upgrade is allowed to fail, everything after it still runs, and the failure is
# reported (and the exit status set) at the end.
upgrade_ok=true

if [[ -n "$filter" ]]; then
  mapfile -t tools < <(mise ls --current | awk '{print $1}' | sort -u | grep -iF -- "$filter" || true)
  if [[ ${#tools[@]} -eq 0 ]]; then
    err "no mise tools match '$filter'"
    exit 1
  fi

  say "$CYAN" "Upgrading" "${tools[*]}"
  refresh_branch_tools "${tools[@]}"
  mise_upgrade "${tools[@]}" || upgrade_ok=false
  sync_rustup_default
  mise prune --yes "${tools[@]}" || warn "mise prune failed; continuing"

  if printf '%s\n' "${tools[@]}" | grep -q '^npm:'; then
    "$HOME/dotfiles/scripts/install/fix-mise-npm-installs.sh"
  fi

  report_disk_usage
  if ! $upgrade_ok; then
    err "mise upgrade failed for at least one tool, see above"
    exit 1
  fi
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

say "$CYAN" "Checking" "branch-pinned tools for new commits"
refresh_branch_tools

say "$CYAN" "Upgrading" "mise tools"
mise_upgrade || upgrade_ok=false
sync_rustup_default
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

if ! $upgrade_ok; then
  err "mise upgrade failed for at least one tool, see above"
  exit 1
fi

exit 0
