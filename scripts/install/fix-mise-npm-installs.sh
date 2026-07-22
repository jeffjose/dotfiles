#!/usr/bin/env bash
#
# Repair mise's npm: backend tools after the aube store is lost.
#
# mise installs npm: tools with aube, which does NOT copy package contents into
# the install dir. It hard/sym-links them out of a content-addressed store at
# ~/.cache/aube/virtual-store (2GB+). So this:
#
#   ~/.local/share/mise/installs/npm-pnpm/11.15.1/bin/pnpm
#     -> .../global-aube/<hash>/node_modules/pnpm/bin/pnpm.mjs
#     -> .aube/pnpm@11.15.1 -> ~/.cache/aube/virtual-store/pnpm@11.15.1-<hash>
#
# is a chain that ends in ~/.cache. Anything that clears ~/.cache -- `rm -rf
# ~/.cache`, a cleaner, a disk-full purge -- leaves every npm: tool as a pile of
# dangling symlinks. mise still reports them installed and active, `which pnpm`
# still finds the shim, and the failure surfaces as garbage further downstream
# (pnpm falls through to corepack, which then dies on its own signing-key bug).
#
# `mise upgrade` does not fix this: the version on disk is already current, so
# there is nothing to upgrade. Only a forced reinstall re-populates the store.
#
# Detection is deliberately structural rather than "run --version on each tool":
# find -L reports symlinks it cannot resolve, which is exactly the failure, and
# costs no process spawns for tools that are fine.
#
# Jeffrey Jose | 2026-07-22
#
set -euo pipefail

export npm_config_ignore_scripts=false
export npm_config_omit=

if ! command -v mise >/dev/null 2>&1; then
  echo "mise not on PATH; nothing to repair."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  jq not found; skipping npm: backend health check." >&2
  exit 0
fi

echo "Checking mise npm: tools for a lost aube store..."

# tool<TAB>install_path for every active npm:-backend tool.
mapfile -t entries < <(
  mise ls --current --json 2>/dev/null |
    jq -r 'to_entries[] as $e
             | select($e.key | startswith("npm:"))
             | $e.value[]
             | select(.installed and .active)
             | "\($e.key)\t\(.install_path)"'
)

broken=()
for entry in "${entries[@]}"; do
  tool="${entry%%$'\t'*}"
  path="${entry#*$'\t'}"

  [[ -d "$path" ]] || { broken+=("$tool"); continue; }

  # -xtype l == a symlink whose target does not resolve.
  if [[ -n "$(find "$path" -type l -xtype l -print -quit 2>/dev/null)" ]]; then
    broken+=("$tool")
  fi
done

if [[ ${#broken[@]} -eq 0 ]]; then
  echo "✓ all ${#entries[@]} npm: tools intact"
  exit 0
fi

echo "Found ${#broken[@]} npm: tool(s) with dangling links (aube store was cleared):"
printf '  - %s\n' "${broken[@]}"

# One `mise install --force` for the lot: aube dedupes the shared store, so a
# single batch is much faster than one invocation per tool.
if ! mise install --force "${broken[@]}"; then
  echo "⚠️  batch reinstall reported errors; retrying individually..." >&2
  for tool in "${broken[@]}"; do
    mise install --force "$tool" || echo "  ✗ $tool" >&2
  done
fi

mise reshim

# Re-check. Anything still dangling needs a human.
still_broken=()
for entry in "${entries[@]}"; do
  tool="${entry%%$'\t'*}"
  path="$(mise where "$tool" 2>/dev/null || true)"
  [[ -n "$path" && -d "$path" ]] || { still_broken+=("$tool"); continue; }
  if [[ -n "$(find "$path" -type l -xtype l -print -quit 2>/dev/null)" ]]; then
    still_broken+=("$tool")
  fi
done

if [[ ${#still_broken[@]} -gt 0 ]]; then
  echo "✗ still broken after reinstall:" >&2
  printf '  - %s\n' "${still_broken[@]}" >&2
  echo "  Check ~/.npmrc and \`mise install --force <tool>\` output by hand." >&2
  exit 1
fi

echo "✓ repaired ${#broken[@]} npm: tool(s)"
exit 0
