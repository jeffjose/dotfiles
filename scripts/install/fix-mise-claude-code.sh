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
# Strategy:
#   1. If claude already runs, exit clean.
#   2. Find install.cjs under the active install dir and run it.
#   3. If still broken, force a clean reinstall via mise, then re-run install.cjs.
#   4. Verify; report and exit non-zero if it didn't take.

set -euo pipefail

export npm_config_ignore_scripts=false
export npm_config_omit=

claude_works() {
  local cmd="${1:-claude}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    return 1
  fi
  # Verify it's actually working and not the stub
  "$cmd" --version >/dev/null 2>&1
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

# Check if the primary mise-installed version works
install_dir="$(mise where 'npm:@anthropic-ai/claude-code' 2>/dev/null || true)"
claude_bin="claude"
if [[ -n "$install_dir" ]]; then
  claude_bin="$install_dir/bin/claude"
fi

if claude_works "$claude_bin"; then
  echo "✓ claude already works ($claude_bin)"
  exit 0
fi

if [[ -n "$install_dir" && -d "$install_dir" ]]; then
  if run_postinstall_in "$install_dir" && claude_works "$claude_bin"; then
    echo "✓ claude fixed via postinstall"
    exit 0
  fi
fi

echo "Reinstalling @anthropic-ai/claude-code via mise..."
mise uninstall 'npm:@anthropic-ai/claude-code' >/dev/null 2>&1 || true
mise install
mise reshim

# Re-check install_dir after reinstall
install_dir="$(mise where 'npm:@anthropic-ai/claude-code' 2>/dev/null || true)"
if [[ -n "$install_dir" ]]; then
  claude_bin="$install_dir/bin/claude"
  if [[ -d "$install_dir" ]]; then
    run_postinstall_in "$install_dir" || true
  fi
fi

if claude_works "$claude_bin"; then
  echo "✓ claude fixed via reinstall"
  exit 0
fi

echo "✗ claude still broken — manual investigation needed" >&2
echo "  install_dir=$install_dir" >&2
echo "  Check: ~/.npmrc, mise --version, mise ls 'npm:@anthropic-ai/claude-code'" >&2
exit 1
