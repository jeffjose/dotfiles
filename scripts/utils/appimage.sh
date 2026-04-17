#!/bin/bash
#
# appimage — install an AppImage to ~/bin with a simple kebab-case name.
# Accepts a URL or a local .AppImage path.
#
# Jeffrey Jose | 2026-04-16

set -euo pipefail

BIN_DIR="${HOME}/bin"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <url-or-appimage-path>" >&2
  exit 1
fi

arg="$1"
mkdir -p "$BIN_DIR"

tmpdir=""
trap '[ -n "$tmpdir" ] && rm -rf "$tmpdir"' EXIT

# Resolve a GitHub release page URL to a direct .AppImage asset URL.
# Supports:
#   https://github.com/OWNER/REPO
#   https://github.com/OWNER/REPO/releases
#   https://github.com/OWNER/REPO/releases/latest
#   https://github.com/OWNER/REPO/releases/tag/TAG
resolve_github() {
  local url="$1" owner repo tag api
  if [[ "$url" =~ ^https?://github\.com/([^/]+)/([^/]+)(/releases(/tag/([^/?#]+)|/latest)?)?/?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]%.git}"
    tag="${BASH_REMATCH[5]:-}"
    if [ -n "$tag" ]; then
      api="https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}"
    else
      api="https://api.github.com/repos/${owner}/${repo}/releases/latest"
    fi
    echo "Resolving GitHub release: ${owner}/${repo}${tag:+ @ $tag}" >&2
    local hdrs=(-H "Accept: application/vnd.github+json")
    [ -n "${GITHUB_TOKEN:-}" ] && hdrs+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    local json
    json=$(curl -sfL "${hdrs[@]}" "$api") || { echo "GitHub API request failed: $api" >&2; return 1; }
    # Prefer x86_64/linux AppImages; fall back to any AppImage.
    local asset
    asset=$(jq -r '[.assets[] | select(.name | test("\\.AppImage$"; "i"))] as $a
      | ($a | map(select(.name | test("x86[_-]?64|linux"; "i"))) + $a)
      | .[0].browser_download_url // empty' <<<"$json")
    if [ -z "$asset" ]; then
      echo "No .AppImage asset found in release" >&2
      return 1
    fi
    echo "$asset"
    return 0
  fi
  return 1
}

if [[ "$arg" =~ ^https?://github\.com/ ]]; then
  resolved=$(resolve_github "$arg") || exit 1
  echo "Asset: $resolved"
  arg="$resolved"
fi

if [[ "$arg" =~ ^https?:// ]]; then
  tmpdir=$(mktemp -d)
  echo "Downloading $arg ..."
  ( cd "$tmpdir" && curl -fLOJ --progress-bar "$arg" )
  src=$(find "$tmpdir" -maxdepth 1 -type f | head -n1)
  if [ -z "$src" ]; then
    echo "Download failed: no file produced" >&2
    exit 1
  fi
else
  if [ ! -f "$arg" ]; then
    echo "File not found: $arg" >&2
    exit 1
  fi
  src="$arg"
fi

filename=$(basename "$src")

# Derive simple kebab-case name:
#   1. strip .AppImage (case-insensitive)
#   2. strip first version-ish token and everything after (-v?1.2.3, -x86_64, etc.)
#   3. CamelCase -> kebab-case
#   4. normalize separators, lowercase, collapse hyphens
name=$(printf '%s' "$filename" \
  | sed -E 's/\.[Aa]pp[Ii]mage$//' \
  | sed -E 's/[-_.]v?[0-9].*$//' \
  | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' \
  | tr '[:upper:]' '[:lower:]' \
  | tr '_ ' '--' \
  | sed -E 's/-+/-/g; s/^-+//; s/-+$//')

if [ -z "$name" ]; then
  echo "Could not derive a name from: $filename" >&2
  exit 1
fi

dest="$BIN_DIR/$name"

if [ -e "$dest" ]; then
  echo "Overwriting existing: $dest"
fi

mv -f "$src" "$dest"
chmod +x "$dest"

echo "Installed: $dest"
