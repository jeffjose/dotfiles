#!/usr/bin/env bash
#
# Repair @anthropic-ai/claude-code installed via mise's npm: backend.
#
# claude-code ships its native binary as a platform-specific optionalDependency
# plus a postinstall (install.cjs) that wires it into the bin shim. Some npm
# configs (ignore-scripts=true, omit=optional) silently break this on install,
# leaving the JS launcher to error with "claude native binary not installed"
# at runtime.
#
# Strategy:
#   1. Force npm config that lets postinstall + optional deps work.
#   2. If claude already runs, exit clean.
#   3. Try the cheap fix: invoke install.cjs in place.
#   4. Fall back to a clean reinstall via mise.
#   5. Verify claude actually runs; report and exit non-zero if not.

set -euo pipefail

export npm_config_ignore_scripts=false
export npm_config_omit=

install_root="$HOME/.local/share/mise/installs/npm-@anthropic-ai/claude-code"

claude_works() {
  command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1
}

if claude_works; then
  echo "✓ claude already works — nothing to do"
  exit 0
fi

install_cjs=""
if [[ -d "$install_root" ]]; then
  install_cjs="$(find "$install_root" -maxdepth 6 \
    -path '*/@anthropic-ai/claude-code/install.cjs' 2>/dev/null | head -n 1 || true)"
fi

if [[ -n "$install_cjs" ]]; then
  echo "Running claude-code postinstall: $install_cjs"
  if node "$install_cjs" && claude_works; then
    echo "✓ claude fixed via in-place postinstall"
    exit 0
  fi
fi

echo "Reinstalling @anthropic-ai/claude-code via mise..."
rm -rf "$HOME/.local/share/mise/installs/npm-@anthropic-ai"
mise install 'npm:@anthropic-ai/claude-code@latest'
mise reshim

if claude_works; then
  echo "✓ claude fixed via clean reinstall"
  exit 0
fi

echo "✗ claude still broken after reinstall — manual investigation needed" >&2
echo "  Check: ~/.npmrc, npm config get ignore-scripts, npm config get omit" >&2
exit 1
