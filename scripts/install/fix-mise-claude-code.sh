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
  command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1
}

run_postinstall_in() {
  local dir="$1" cjs
  cjs="$(find "$dir" -name install.cjs -path '*/@anthropic-ai/claude-code/install.cjs' 2>/dev/null | head -n 1)"
  if [[ -z "$cjs" ]]; then
    return 1
  fi
  echo "Running claude-code postinstall: $cjs"
  node "$cjs"
}

if claude_works; then
  echo "✓ claude already works"
  exit 0
fi

install_dir="$(mise where 'npm:@anthropic-ai/claude-code' 2>/dev/null || true)"
if [[ -n "$install_dir" && -d "$install_dir" ]]; then
  if run_postinstall_in "$install_dir" && claude_works; then
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

if claude_works; then
  echo "✓ claude fixed via reinstall"
  exit 0
fi

echo "✗ claude still broken — manual investigation needed" >&2
echo "  install_dir=$install_dir" >&2
echo "  Check: ~/.npmrc, mise --version, mise ls 'npm:@anthropic-ai/claude-code'" >&2
exit 1
