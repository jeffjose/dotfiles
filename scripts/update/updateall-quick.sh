#!/bin/bash
#
# uq — the quick update: dotfiles, then every update script below.
#
# Usage: uq [-v|--verbose]
#
#   -v, --verbose   also list what did not change in the closing summary
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
SCRIPTS_DIR="$HOME/dotfiles/scripts/update"
UPDATE_SCRIPTS=(
  "update_code.sh"
  #"update_cursor.sh"
  "update_mise.sh"
  "update_deb.sh"
  "update_claude_desktop.sh"
  "update_appimage.sh"
  #"update_rust.sh"  # Currently disabled
)

# Output is cargo-style, like ./setup: a right-aligned coloured verb, then the
# detail. The update scripts print their own progress in between; the summary at
# the end lists only what changed.
source "$HOME/dotfiles/scripts/lib/ui.sh"
source "$HOME/dotfiles/scripts/lib/host.sh"

VERBOSE=0
case "${1:-}" in
  -v | --verbose) VERBOSE=1 ;;
  -h | --help)
    sed -n '3,/^$/s/^# \{0,1\}//p' "$0"
    exit 0
    ;;
esac

# Everything a run can change, as "kind<TAB>name<TAB>version<TAB>id" lines: mise
# and its tools, the debs in misc/package.toml, and every managed AppImage.
# Taken before and after the run, the difference is the summary.
#
# `id` is "-" except for AppImages, where it is the release tag. Rolling repos
# keep the release name at the upstream version and move only the tag, so the
# version alone would miss a rebuild.
snapshot() {
  if command -v mise >/dev/null 2>&1; then
    printf 'mise\tmise\t%s\t-\n' "$(mise --version 2>/dev/null | awk 'NR==1 {print $1}')"
    mise ls --current --json 2>/dev/null |
      jq -r 'to_entries[] | .key as $k | .value[]
             | select(.installed and .active)
             | "mise\t\($k)\t\(.version)\t-"' 2>/dev/null || true
  fi

  # update_deb.sh installs whatever misc/package.toml lists — read the names
  # from the toml rather than hardcoding them so the summary tracks the config.
  local toml="$HOME/dotfiles/misc/package.toml" pkg ver
  if [[ -f "$toml" ]]; then
    while read -r pkg; do
      [[ -n "$pkg" ]] || continue
      ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null) || ver=""
      [[ -n "$ver" ]] && printf 'deb\t%s\t%s\t-\n' "$pkg" "$ver"
    done < <(sed -nE 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$toml")
  fi

  # A release name that is really the asset filename is noise; fall back to the
  # tag, as `appimage list` does.
  local meta
  for meta in "$HOME"/bin/.appimage/meta/*.json; do
    [[ -e "$meta" ]] || continue
    jq -r '(.release_name // "") as $r | (.tag // "") as $t
           | (if $r == "" or ($r | test("\\.appimage$"; "i")) then $t else $r end) as $v
           | "appimage\t\(.name)\t\(if $v == "" then "-" else $v end)\t\(if $t == "" then "-" else $t end)"' \
      "$meta" 2>/dev/null || true
  done
}

declare -A before_ver before_id after_ver after_id
declare -a after_keys=()

# record <before|after>: store a snapshot, keyed by "kind/name"
record() {
  local -n ver="${1}_ver" id="${1}_id"
  local kind name v i
  while IFS=$'\t' read -r kind name v i; do
    ver["$kind/$name"]="$v"
    id["$kind/$name"]="$i"
    [[ "$1" == "after" ]] && after_keys+=("$kind/$name")
  done < <(snapshot)
  return 0
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
    say "$DIM" "Skipping" "sudo warm-up — no sudo on this host"
    return 0
  fi

  # Already usable without a prompt (NOPASSWD sudoers, or a still-warm cache).
  # Nothing to ask for, and nothing worth keeping alive.
  if sudo -n true 2>/dev/null; then
    return 0
  fi

  say "$CYAN" "Asking" "for sudo up front so the rest of the run is unattended"
  if ! sudo -v; then
    warn "couldn't pre-authorise sudo; steps that need root will prompt when they get there"
    return 0
  fi

  # Only worth a keepalive if the credential actually caches. Where it doesn't
  # (touch-per-command setups), `sudo -v` succeeds but leaves nothing behind, so
  # the loop would just churn — skip it.
  if ! sudo -n true 2>/dev/null; then
    say "$DIM" "Skipping" "sudo refresh loop — credentials don't cache here"
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

# On a corp host, say first thing what this run will leave alone — before the
# sudo prompt, so it is the line on screen when the run starts.
corp_notice() {
  is_corp_host || return 0
  local -a apps=() tools=()
  mapfile -t apps < <(corp_blocked_appimages)
  mapfile -t tools < <(corp_blocked_mise_tools)

  say "$YELLOW" "CORP MACHINE" "${BOLD}the following will NOT be installed or updated here$RESET"
  [ ${#apps[@]} -eq 0 ] || detail "appimages   ${apps[*]}"
  [ ${#tools[@]} -eq 0 ] || detail "mise tools  ${tools[*]}"
  echo
}

declare -a failed_updates=()

# run_update_script <script> <n>: run one update script and report how it went
run_update_script() {
  local script="$1" n="$2"
  local step=${script#update_} # Remove 'update_' prefix
  step=${step%.sh}             # Remove '.sh' suffix
  step=${step//_/-}
  local started status=0
  started=$(now_us)

  echo
  say "$CYAN" "Updating" "$step $DIM[$n/${#UPDATE_SCRIPTS[@]}]$RESET"

  if [ ! -x "$SCRIPTS_DIR/$script" ]; then
    say "$RED" "Failed" "$step — $script not found or not executable"
    failed_updates+=("$step")
    return 1
  fi

  "$SCRIPTS_DIR/$script" || status=$?
  if [ $status -eq 0 ]; then
    say "$GREEN" "Done" "$step ${DIM}in $(elapsed "$started")$RESET"
  else
    say "$RED" "Failed" "$step (exit $status) ${DIM}after $(elapsed "$started")$RESET"
    failed_updates+=("$step")
  fi
  return $status
}

# Print what changed between the two snapshots, then the closing line
print_summary() {
  local key kind name old new verb colour
  local -a rows=()
  local updated=0 unchanged=0 width=0 US=$'\x1f' # not whitespace, so empty fields survive `read`

  for key in "${after_keys[@]}"; do
    kind=${key%%/*}
    name=${key#*/}
    new=${after_ver[$key]}
    if [[ -z "${before_ver[$key]+set}" ]]; then
      verb="Installed" colour="$GREEN"
    elif [[ "${before_ver[$key]}" != "$new" ]]; then
      verb="Updated" colour="$GREEN" new="${before_ver[$key]} → $new"
    elif [[ "${before_id[$key]}" != "${after_id[$key]}" ]]; then
      # Same version, different build: show the tags, the part that differs.
      verb="Updated" colour="$GREEN" new="${before_id[$key]} → ${after_id[$key]}"
    else
      ((unchanged++)) || true
      [ $VERBOSE -eq 1 ] || continue
      verb="Fresh" colour="$DIM"
    fi
    [[ "$verb" == "Fresh" ]] || ((updated++)) || true
    ((${#name} > width)) && width=${#name}
    rows+=("$colour$US$verb$US$name$US$new$US$kind")
  done

  echo
  local row
  for row in "${rows[@]}"; do
    IFS=$US read -r colour verb name new kind <<<"$row"
    if [[ "$verb" == "Fresh" ]]; then
      say "$colour" "$verb" "$(printf '%s%-*s  %s  (%s)%s' "$DIM" "$width" "$name" "$new" "$kind" "$RESET")"
    else
      say "$colour" "$verb" "$(printf '%s%-*s%s  %s  %s(%s)%s' "$BOLD" "$width" "$name" "$RESET" "$new" "$DIM" "$kind" "$RESET")"
    fi
  done

  local summary="${#UPDATE_SCRIPTS[@]} steps in $(elapsed "$start_us"): $updated updated, $unchanged unchanged"
  if [ ${#failed_updates[@]} -gt 0 ]; then
    local failed
    failed=$(printf ', %s' "${failed_updates[@]}")
    say "$RED" "Finished" "$summary, ${#failed_updates[@]} failed (${failed#, })"
    return 1
  fi
  say "$GREEN" "Finished" "$summary"
}

# Main execution
main() {
  start_us=$(now_us)

  corp_notice
  check_sudo

  # Update dotfiles first (best-effort — don't abort the whole update run if the
  # pull fails, e.g. offline, merge conflict, or detached HEAD). Subshell keeps a
  # failed cd/pull from stranding us in the wrong directory.
  say "$CYAN" "Updating" "dotfiles"
  if ! (cd ~/dotfiles && git pull && ./setup); then
    warn "dotfiles update failed; continuing with the rest of the updates"
  fi

  check_sudo
  record before

  # Run updates
  local n=0 script
  for script in "${UPDATE_SCRIPTS[@]}"; do
    ((n++)) || true
    run_update_script "$script" "$n" || true # Continue on error
  done

  record after
  print_summary
}

# Run main function
main "$@"
