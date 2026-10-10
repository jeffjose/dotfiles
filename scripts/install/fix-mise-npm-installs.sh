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

source "$HOME/dotfiles/scripts/lib/ui.sh"

if ! command -v mise >/dev/null 2>&1; then
  say "$DIM" "Skipping" "npm: tool check — mise not on PATH"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found; skipping npm: backend health check"
  exit 0
fi

say "$CYAN" "Checking" "mise npm: tools for a lost aube store"

# tool<TAB>install_path for every active npm:-backend tool.
mapfile -t entries < <(
  mise ls --current --json 2>/dev/null |
    jq -r 'to_entries[] as $e
             | select($e.key | startswith("npm:"))
             | $e.value[]
             | select(.installed and .active)
             | "\($e.key)\t\(.install_path)"'
)

# True if $1 has a dangling symlink whose target lies OUTSIDE the install dir,
# i.e. into the aube store under ~/.cache. Dangling links that stay inside the
# install dir are optional per-platform deps (foo-darwin-arm64, foo-win32-x64,
# fsevents, ...) that were deliberately skipped; they are normal, not damage.
has_lost_store_links() {
  local root link target
  root="$(realpath -m "$1")"
  while IFS= read -r -d '' link; do
    target="$(readlink "$link")"
    [[ "$target" == /* ]] || target="$(dirname "$link")/$target"
    target="$(realpath -m "$target")"
    [[ "$target" == "$root"/* ]] || return 0
  done < <(find "$1" -type l -xtype l -print0 2>/dev/null)
  return 1
}

broken=()
for entry in "${entries[@]}"; do
  tool="${entry%%$'\t'*}"
  path="${entry#*$'\t'}"

  [[ -d "$path" ]] || { broken+=("$tool"); continue; }

  if has_lost_store_links "$path"; then
    broken+=("$tool")
  fi
done

if [[ ${#broken[@]} -eq 0 ]]; then
  say "$DIM" "Fresh" "${DIM}all ${#entries[@]} npm: tools intact$RESET"
  exit 0
fi

say "$YELLOW" "Repairing" "${#broken[@]} npm: tool(s) with dangling links (aube store was cleared)"
for tool in "${broken[@]}"; do detail "$tool"; done

# One `mise install --force` for the lot: aube dedupes the shared store, so a
# single batch is much faster than one invocation per tool.
if ! mise install --force "${broken[@]}"; then
  warn "batch reinstall reported errors; retrying individually"
  for tool in "${broken[@]}"; do
    mise install --force "$tool" || say "$RED" "Failed" "$tool" >&2
  done
fi

mise reshim

# Re-check. Anything still dangling needs a human.
still_broken=()
for entry in "${entries[@]}"; do
  tool="${entry%%$'\t'*}"
  path="$(mise where "$tool" 2>/dev/null || true)"
  [[ -n "$path" && -d "$path" ]] || { still_broken+=("$tool"); continue; }
  if has_lost_store_links "$path"; then
    still_broken+=("$tool")
  fi
done

if [[ ${#still_broken[@]} -gt 0 ]]; then
  err "still broken after reinstall: ${still_broken[*]}"
  detail "check ~/.npmrc and \`mise install --force <tool>\` output by hand" >&2
  exit 1
fi

say "$GREEN" "Repaired" "${#broken[@]} npm: tool(s)"
exit 0
