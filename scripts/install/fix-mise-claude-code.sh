#!/usr/bin/env bash
#
# Repair @anthropic-ai/claude-code installed via mise's npm: backend.
#
# claude-code ships its native binary as a platform-specific optionalDependency
# plus a postinstall (install.cjs) that wires it into the bin shim. Some
# installers (aube, certain npm/pnpm configs) silently skip the postinstall,
# leaving bin/claude as a stub that just prints "claude native binary not
# installed" at runtime.
#
# WHAT THIS SCRIPT HEALTH-CHECKS, AND WHY IT MATTERS
#
# It checks `claude` as resolved through PATH -- the binary you actually get when
# you type it -- and nothing else. Earlier revisions probed the mise install dir
# directly via `mise where`, which was wrong in a way that hid a real outage for
# weeks: a second, node-global `npm install -g` copy under
# node/<ver>/lib/node_modules wins PATH resolution over the npm: backend, and
# Claude Code's own auto-updater maintains that copy in place, outside mise. So
# `uq` cheerfully reported "✓ claude already works" about a healthy install
# nobody ran, while the shadowing copy SIGBUSed on every invocation.
#
# The rule that keeps this honest: health-check what the user runs, repair what
# mise owns, and refuse to claim success on the strength of a different binary.
#
# Strategy:
#   1. Flag any non-mise install shadowing PATH -- uq cannot keep those healthy.
#   2. If the PATH-resolved claude runs, exit clean.
#   3. Find install.cjs under the active install dir and run it.
#   4. If still broken, force a clean reinstall via mise, then re-run install.cjs.
#   5. Verify through PATH again; report and exit non-zero if it didn't take.

set -euo pipefail

export npm_config_ignore_scripts=false
export npm_config_omit=

# End-to-end check: run the thing and see if it runs. Existence, executability
# and the right filename all pass on a corrupt install, so none of them are
# worth testing -- only the exit status is.
claude_works() {
  local cmd="${1:-claude}"
  command -v "$cmd" >/dev/null 2>&1 || return 1
  "$cmd" --version >/dev/null 2>&1
}

# A truncated native binary defeats every static check: present, executable,
# correctly named, plausible size. It only fails when the loader touches a page
# past EOF and the kernel delivers SIGBUS. `file` names the shortfall directly
# ("missing section headers at N"), which is the cheapest reliable signal.
#
# This happens when an install runs out of disk midway -- the giveaway is a size
# that is an exact power of two, the write having stopped on a buffer boundary.
binary_is_truncated() {
  local f
  f="$(readlink -f "${1:-}" 2>/dev/null)" || return 1
  [[ -f "$f" ]] || return 1
  file -L "$f" 2>/dev/null | grep -q 'missing section headers'
}

# mise is not the only installer of claude-code. A global npm install inside the
# active node toolchain shadows the npm: backend on PATH, and Claude Code's
# auto-updater then owns it -- meaning uq neither updates nor repairs the copy
# that actually runs. Report it loudly; repairing around it is not possible.
warn_shadowing_installs() {
  local node_prefix shadow found=1
  while read -r node_prefix; do
    [[ -n "$node_prefix" ]] || continue
    shadow="$node_prefix/lib/node_modules/@anthropic-ai/claude-code"
    if [[ -d "$shadow" ]]; then
      echo "⚠️  A node-global claude-code is shadowing the mise install:" >&2
      echo "      $shadow" >&2
      echo "    It wins PATH resolution and self-updates outside mise, so uq" >&2
      echo "    cannot keep it healthy. Remove it with:" >&2
      echo "      PATH=$node_prefix/bin:\$PATH npm uninstall -g @anthropic-ai/claude-code" >&2
      found=0
    fi
  done < <(find "$HOME/.local/share/mise/installs/node" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  return $found
}

# Locate the launcher inside a mise npm: install dir. mise has shipped two
# layouts: a top-level bin/ and, with the aube-backed npm: backend, only
# node_modules/.bin/. Checking just one makes a healthy install look broken.
resolve_claude_bin() {
  local dir="$1" candidate
  for candidate in "$dir/bin/claude" "$dir/node_modules/.bin/claude"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

run_postinstall_in() {
  local dir="$1" cjs
  cjs="$(find -L "$dir" -name install.cjs -path '*/@anthropic-ai/claude-code/install.cjs' 2>/dev/null | head -n 1)"
  if [[ -z "$cjs" ]]; then
    return 1
  fi
  echo "Running claude-code postinstall: $cjs"
  node "$cjs"
}

install_dir="$(mise where 'npm:@anthropic-ai/claude-code' 2>/dev/null || true)"

warn_shadowing_installs || true

# Health-check PATH, not the install dir. See the header.
if claude_works claude; then
  echo "✓ claude already works ($(mise which claude 2>/dev/null || command -v claude))"
  exit 0
fi

resolved="$(mise which claude 2>/dev/null || command -v claude 2>/dev/null || true)"
if [[ -n "$resolved" ]] && binary_is_truncated "$resolved"; then
  echo "✗ claude's native binary is truncated (interrupted or out-of-disk install):" >&2
  echo "    $(readlink -f "$resolved") -- $(stat -Lc %s "$resolved" 2>/dev/null) bytes" >&2
  df -h "$HOME" | tail -1 >&2
fi

if [[ -n "$install_dir" && -d "$install_dir" ]]; then
  if run_postinstall_in "$install_dir" && claude_works claude; then
    echo "✓ claude fixed via postinstall"
    exit 0
  fi
fi

echo "Reinstalling @anthropic-ai/claude-code via mise..."
mise uninstall 'npm:@anthropic-ai/claude-code' >/dev/null 2>&1 || true
mise install
mise reshim

install_dir="$(mise where 'npm:@anthropic-ai/claude-code' 2>/dev/null || true)"
if [[ -n "$install_dir" && -d "$install_dir" ]]; then
  run_postinstall_in "$install_dir" || true
fi

if claude_works claude; then
  echo "✓ claude fixed via reinstall"
  exit 0
fi

echo "✗ claude still broken — manual investigation needed" >&2
echo "  PATH claude: $(command -v claude 2>/dev/null || echo 'not on PATH')" >&2
echo "  mise which : $(mise which claude 2>/dev/null || echo 'unresolved')" >&2
echo "  install_dir: $install_dir" >&2
echo "  Check: ~/.npmrc, mise --version, mise ls 'npm:@anthropic-ai/claude-code'" >&2
exit 1
