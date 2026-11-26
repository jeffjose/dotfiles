# Prompt for the sudo password up front and keep the credential warm.
#
# Source this file after ui.sh; it only defines functions. Shared by firstrun
# and uq so long runs ask for sudo once at the start instead of mid-run, and
# clean up the background refresh loop (including its child sleep) on exit.

SUDO_KEEPALIVE_PID=""

stop_sudo_keepalive() {
  [[ -n "$SUDO_KEEPALIVE_PID" ]] || return 0

  # Note the loop's in-flight `sleep` before killing the loop itself: killing a
  # subshell doesn't kill its children, so the sleep would otherwise hang around
  # orphaned for up to a minute after the script exits.
  local -a children=()
  mapfile -t children < <(pgrep -P "$SUDO_KEEPALIVE_PID" 2>/dev/null || true)
  kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  if [[ ${#children[@]} -gt 0 ]]; then
    kill "${children[@]}" 2>/dev/null || true
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
# None of that should stop the run — steps that need root will prompt for
# themselves if pre-authorisation didn't stick.
check_sudo() {
  # Safe to call more than once (e.g. on both sides of a dotfiles pull).
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
