#!/bin/bash
#
# appimage — tiny AppImage manager.
#
# Subcommands:
#   install <url-or-path>        download / copy & register an AppImage
#   list                         show managed AppImages
#   update <name> | --all        re-check GitHub source and upgrade if newer
#   remove <name>                delete binary, wrapper, desktop entry, metadata
#   migrate [<name>]             adopt pre-existing ~/bin/<name> AppImages
#
# If the first arg looks like a URL or an .AppImage path, `install` is implied.
#
# Layout:
#   ~/bin/<name>                              wrapper script (what you run)
#   ~/bin/.appimage/bin/<name>.AppImage       actual binary
#   ~/bin/.appimage/icons/<name>.<ext>        extracted icon
#   ~/bin/.appimage/meta/<name>.json          metadata (source, tag, sha256, ...)
#   ~/.local/share/applications/<name>.desktop  launcher entry
#
# Jeffrey Jose | 2026-04-18

set -euo pipefail

BIN_DIR="${HOME}/bin"
APPIMAGE_DIR="${BIN_DIR}/.appimage"
APPIMAGE_BIN_DIR="${APPIMAGE_DIR}/bin"
META_DIR="${APPIMAGE_DIR}/meta"
ICON_DIR="${APPIMAGE_DIR}/icons"
APP_DIR="${HOME}/.local/share/applications"

_TMPDIRS=()
_cleanup_tmpdirs() {
  local d
  for d in "${_TMPDIRS[@]+"${_TMPDIRS[@]}"}"; do
    if [ -n "$d" ] && [ -d "$d" ]; then rm -rf "$d"; fi
  done
  return 0
}
trap _cleanup_tmpdirs EXIT

mktmp() {
  local d
  d=$(mktemp -d)
  _TMPDIRS+=("$d")
  echo "$d"
}

usage() {
  cat >&2 <<EOF
Usage:
  $(basename "$0") install [--unofficial] <url-or-path>
  $(basename "$0") list
  $(basename "$0") update <name>
  $(basename "$0") update --all
  $(basename "$0") remove <name>
  $(basename "$0") migrate [<name>]

If the first arg looks like a URL or an AppImage path, \`install\` is implied.
--unofficial tags an AppImage as a community/3rd-party build (shown in list).
EOF
  exit 1
}

# --- helpers -----------------------------------------------------------------

# Resolve a GitHub release page URL to "ASSET_URL<TAB>TAG".
# Supports:
#   https://github.com/OWNER/REPO
#   https://github.com/OWNER/REPO/releases
#   https://github.com/OWNER/REPO/releases/latest
#   https://github.com/OWNER/REPO/releases/tag/TAG
resolve_github() {
  local url="$1" owner repo tag api
  if [[ "$url" =~ ^https?://github\.com/([^/]+)/([^/?#]+)(/releases(/tag/([^/?#]+)|/latest)?)?/?$ ]]; then
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
    jq -r '
      . as $r
      | ([$r.assets[] | select(.name | test("\\.AppImage$"; "i"))]) as $a
      | (($a | map(select(.name | test("x86[_-]?64|linux"; "i"))) + $a) | .[0].browser_download_url // empty) as $url
      | if ($url == "") then "" else "\($url)\t\($r.tag_name // "")" end
    ' <<<"$json"
    return 0
  fi
  return 1
}

github_repo_from_url() {
  local url="$1"
  if [[ "$url" =~ ^https?://github\.com/([^/]+)/([^/?#]+) ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
  fi
}

relative_time() {
  local ts="$1" then now diff
  then=$(date -u -d "$ts" +%s 2>/dev/null) || { echo "-"; return; }
  now=$(date -u +%s)
  diff=$((now - then))
  if [ "$diff" -lt 0 ]; then diff=0; fi
  if   [ "$diff" -lt 60 ];        then echo "just now"
  elif [ "$diff" -lt 3600 ];      then echo "$((diff / 60))m ago"
  elif [ "$diff" -lt 86400 ];     then echo "$((diff / 3600))h ago"
  elif [ "$diff" -lt 2592000 ];   then echo "$((diff / 86400))d ago"
  elif [ "$diff" -lt 31536000 ];  then echo "$((diff / 2592000))mo ago"
  else                                 echo "$((diff / 31536000))y ago"
  fi
}

derive_name() {
  printf '%s' "$1" \
    | sed -E 's/\.[Aa]pp[Ii]mage$//' \
    | sed -E 's/[-_.]v?[0-9].*$//' \
    | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' \
    | tr '[:upper:]' '[:lower:]' \
    | tr '_ ' '--' \
    | sed -E 's/-+/-/g; s/^-+//; s/-+$//'
}

is_appimage() {
  local f="$1"
  [ -f "$f" ] || return 1
  # ELF magic + AppImage type-2 magic bytes at offset 8 (0x41 0x49 0x02)
  local magic
  magic=$(head -c 12 -- "$f" 2>/dev/null | od -An -tx1 -N12 | tr -d ' \n')
  case "$magic" in
    7f454c46*41490[12]*) return 0 ;;
  esac
  return 1
}

write_wrapper() {
  local name="$1" target="$2"
  cat > "$BIN_DIR/$name" <<EOF
#!/bin/sh
exec "$target" "\$@"
EOF
  chmod +x "$BIN_DIR/$name"
}

install_desktop_entry() {
  local name="$1" appimage_path="$2"
  local extract_root
  extract_root=$(mktmp)
  ( cd "$extract_root" && "$appimage_path" --appimage-extract >/dev/null 2>&1 ) || return 0
  # squashfs-root may be a symlink (e.g. sharun-based AppImages) — -L follows it.
  local sq="$extract_root/squashfs-root"
  [ -e "$sq" ] || return 0

  local desktop_src
  desktop_src=$(find -L "$sq" -maxdepth 1 -name '*.desktop' -type f 2>/dev/null | head -n1)
  [ -n "$desktop_src" ] || return 0

  # Find icon: prefer Icon=<name> resolution, fall back to .DirIcon.
  local icon_src="" icon_name icon_ext="" icon_dst=""
  icon_name=$(grep -m1 '^Icon=' "$desktop_src" | sed 's/^Icon=//')
  if [ -n "$icon_name" ]; then
    icon_src=$(find -L "$sq" -maxdepth 3 -name "${icon_name}.png" -o -name "${icon_name}.svg" -o -name "${icon_name}.xpm" 2>/dev/null | head -n1)
  fi
  if [ -z "$icon_src" ] && [ -e "$sq/.DirIcon" ]; then
    icon_src=$(readlink -f "$sq/.DirIcon" 2>/dev/null || true)
  fi

  mkdir -p "$ICON_DIR" "$APP_DIR"
  if [ -n "$icon_src" ] && [ -f "$icon_src" ]; then
    icon_ext="${icon_src##*.}"
    # .DirIcon / no-extension case: sniff actual format.
    if [ "$icon_ext" = "$(basename "$icon_src")" ] || [ "$icon_ext" = "DirIcon" ]; then
      case "$(file -b --mime-type "$icon_src" 2>/dev/null)" in
        image/png)     icon_ext=png ;;
        image/svg+xml) icon_ext=svg ;;
        image/x-xpm|image/xpm) icon_ext=xpm ;;
        *)             icon_ext=png ;;
      esac
    fi
    icon_dst="$ICON_DIR/$name.$icon_ext"
    cp -f "$icon_src" "$icon_dst"
  fi

  local desktop_dst="$APP_DIR/$name.desktop"
  awk -v exec_line="Exec=$BIN_DIR/$name" -v icon_line="${icon_dst:+Icon=$icon_dst}" '
    /^Exec=/   { print exec_line; next }
    /^TryExec=/ { next }
    /^Icon=/   { if (icon_line != "") print icon_line; next }
    { print }
  ' "$desktop_src" > "$desktop_dst"
}

remove_desktop_entry() {
  local name="$1"
  rm -f -- "$APP_DIR/$name.desktop"
  rm -f -- "$ICON_DIR/$name".* 2>/dev/null || true
}

write_metadata() {
  local name="$1" source_url="$2" asset_url="$3" tag="$4" github_repo="$5"
  local filename="$6" sha256="$7" target="$8" origin="${9:-install}"
  local unofficial="${10:-false}"
  mkdir -p "$META_DIR"
  jq -n \
    --arg name "$name" \
    --arg source_url "$source_url" \
    --arg asset_url "$asset_url" \
    --arg tag "$tag" \
    --arg github_repo "$github_repo" \
    --arg filename "$filename" \
    --arg sha256 "$sha256" \
    --arg target "$target" \
    --arg origin "$origin" \
    --argjson unofficial "$unofficial" \
    --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{name:$name, source_url:$source_url, asset_url:$asset_url, tag:$tag,
      github_repo:$github_repo, filename:$filename, sha256:$sha256,
      target:$target, origin:$origin, unofficial:$unofficial,
      installed_at:$installed_at}' \
    > "$META_DIR/$name.json"
}

# --- install -----------------------------------------------------------------

cmd_install() {
  local arg="" unofficial="false"
  while [ $# -gt 0 ]; do
    case "$1" in
      --unofficial) unofficial="true"; shift ;;
      -*) echo "Unknown option: $1" >&2; exit 1 ;;
      *) arg="$1"; shift ;;
    esac
  done
  [ -n "$arg" ] || usage
  mkdir -p "$BIN_DIR" "$APPIMAGE_BIN_DIR"

  local source_url="$arg" asset_url="" tag="" github_repo=""
  github_repo=$(github_repo_from_url "$arg" || true)

  if [ -n "$github_repo" ]; then
    local resolved
    resolved=$(resolve_github "$arg") || exit 1
    if [ -z "$resolved" ]; then
      echo "No .AppImage asset found in release" >&2
      exit 1
    fi
    asset_url="${resolved%%$'\t'*}"
    tag="${resolved#*$'\t'}"
    echo "Asset: $asset_url"
    arg="$asset_url"
  fi

  local src filename
  if [[ "$arg" =~ ^https?:// ]]; then
    local dl_dir
    dl_dir=$(mktmp)
    echo "Downloading $arg ..."
    ( cd "$dl_dir" && curl -fLOJ --progress-bar "$arg" )
    src=$(find "$dl_dir" -maxdepth 1 -type f | head -n1)
    [ -n "$src" ] || { echo "Download failed: no file produced" >&2; exit 1; }
    [ -z "$asset_url" ] && asset_url="$arg"
  else
    [ -f "$arg" ] || { echo "File not found: $arg" >&2; exit 1; }
    src="$arg"
  fi
  filename=$(basename "$src")

  local name
  name=$(derive_name "$filename")
  [ -n "$name" ] || { echo "Could not derive name from: $filename" >&2; exit 1; }

  local target="$APPIMAGE_BIN_DIR/$name.AppImage"
  cp -f -- "$src" "$target"
  chmod 0755 "$target"

  local sha256
  sha256=$(sha256sum "$target" | awk '{print $1}')

  rm -f -- "$BIN_DIR/$name"

  write_wrapper "$name" "$target"
  install_desktop_entry "$name" "$target" || true
  write_metadata "$name" "$source_url" "$asset_url" "$tag" "$github_repo" \
                 "$filename" "$sha256" "$target" "install" "$unofficial"

  echo "Installed: $name"
  echo "  Binary:   $target"
  echo "  Wrapper:  $BIN_DIR/$name"
  if [ -n "$tag" ]; then echo "  Version:  $tag"; fi
  if [ -f "$APP_DIR/$name.desktop" ]; then echo "  Launcher: $APP_DIR/$name.desktop"; fi
}

# --- list --------------------------------------------------------------------

cmd_list() {
  mkdir -p "$META_DIR"
  local files=( "$META_DIR"/*.json )
  if [ ! -e "${files[0]}" ]; then
    echo "(no managed AppImages)" >&2
    return 0
  fi
  {
    printf 'NAME\tVERSION\tSOURCE\tINSTALLED\n'
    local f name tag source installed origin
    for f in "${files[@]}"; do
      name=$(jq -r '.name' "$f")
      tag=$(jq -r 'if .tag == "" or .tag == null then "-" else .tag end' "$f")
      origin=$(jq -r '.origin // "install"' "$f")
      source=$(jq -r '
        if .github_repo != "" and .github_repo != null then .github_repo
        elif .source_url != "" and .source_url != null then .source_url
        else "-" end' "$f")
      if [ "$(jq -r '.unofficial // false' "$f")" = "true" ]; then source="$source (unofficial)"; fi
      if [ "$origin" = "migrated" ]; then source="$source (migrated)"; fi
      installed=$(relative_time "$(jq -r '.installed_at' "$f")")
      printf '%s\t%s\t%s\t%s\n' "$name" "$tag" "$source" "$installed"
    done
  } | column -t -s $'\t'
}

# --- update ------------------------------------------------------------------

cmd_update_one() {
  local name="$1"
  local meta="$META_DIR/$name.json"
  [ -f "$meta" ] || { echo "Not managed: $name" >&2; return 1; }

  local source_url github_repo current_tag origin
  source_url=$(jq -r '.source_url // ""' "$meta")
  github_repo=$(jq -r '.github_repo // ""' "$meta")
  current_tag=$(jq -r '.tag // ""' "$meta")
  origin=$(jq -r '.origin // "install"' "$meta")

  if [ -z "$github_repo" ] || [ "$origin" = "migrated" ]; then
    echo "[$name] no tracked source (re-run: appimage install <url> to enable updates)" >&2
    return 0
  fi

  local resolved new_asset new_tag
  resolved=$(resolve_github "$source_url") || { echo "[$name] resolve failed" >&2; return 1; }
  if [ -z "$resolved" ]; then
    echo "[$name] no asset found in latest release" >&2
    return 1
  fi
  new_asset="${resolved%%$'\t'*}"
  new_tag="${resolved#*$'\t'}"

  if [ -n "$current_tag" ] && [ "$new_tag" = "$current_tag" ]; then
    echo "[$name] up-to-date ($current_tag)"
    return 0
  fi

  echo "[$name] ${current_tag:-?} -> ${new_tag:-?}"
  cmd_install "$source_url"
}

cmd_update() {
  if [ "${1:-}" = "--all" ]; then
    local f
    for f in "$META_DIR"/*.json; do
      [ -e "$f" ] || continue
      cmd_update_one "$(jq -r '.name' "$f")" || true
    done
  else
    [ -n "${1:-}" ] || usage
    cmd_update_one "$1"
  fi
}

# --- remove ------------------------------------------------------------------

cmd_remove() {
  local name="$1"
  local meta="$META_DIR/$name.json"
  [ -f "$meta" ] || { echo "Not managed: $name" >&2; exit 1; }
  local target
  target=$(jq -r '.target' "$meta")
  rm -f -- "$BIN_DIR/$name" "$target" "$meta"
  remove_desktop_entry "$name"
  echo "Removed: $name"
}

# --- migrate -----------------------------------------------------------------

migrate_one() {
  local path="$1"
  local filename name target sha256 installed_at
  filename=$(basename "$path")
  name="$filename"   # filename already the desired kebab name in old layout
  target="$APPIMAGE_BIN_DIR/$name.AppImage"

  if [ -f "$META_DIR/$name.json" ]; then
    echo "[$name] already managed, skipping"
    return 0
  fi

  mkdir -p "$APPIMAGE_BIN_DIR"
  mv -f -- "$path" "$target"
  chmod +x "$target"
  sha256=$(sha256sum "$target" | awk '{print $1}')
  installed_at=$(date -u -r "$target" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)

  write_wrapper "$name" "$target"
  install_desktop_entry "$name" "$target" || true

  mkdir -p "$META_DIR"
  jq -n \
    --arg name "$name" \
    --arg filename "$filename" \
    --arg sha256 "$sha256" \
    --arg target "$target" \
    --arg installed_at "$installed_at" \
    '{name:$name, source_url:"", asset_url:"", tag:"", github_repo:"",
      filename:$filename, sha256:$sha256, target:$target,
      origin:"migrated", installed_at:$installed_at}' \
    > "$META_DIR/$name.json"

  echo "Migrated: $name"
}

cmd_migrate() {
  mkdir -p "$BIN_DIR" "$APPIMAGE_BIN_DIR"
  if [ -n "${1:-}" ]; then
    local p="$BIN_DIR/$1"
    [ -f "$p" ] || { echo "Not found: $p" >&2; exit 1; }
    is_appimage "$p" || { echo "Not an AppImage: $p" >&2; exit 1; }
    migrate_one "$p"
    return
  fi
  local found=0 f
  for f in "$BIN_DIR"/*; do
    [ -f "$f" ] || continue       # skip dirs, missing
    if [ -L "$f" ]; then continue; fi
    is_appimage "$f" || continue
    found=1
    migrate_one "$f"
  done
  if [ "$found" -eq 0 ]; then echo "No AppImages to migrate in $BIN_DIR" >&2; fi
}

# --- dispatch ----------------------------------------------------------------

[ $# -ge 1 ] || usage
cmd="$1"
case "$cmd" in
  install) shift; cmd_install "$@" ;;
  list)    shift; cmd_list ;;
  update)  shift; cmd_update "$@" ;;
  remove)  shift; [ $# -eq 1 ] || usage; cmd_remove "$1" ;;
  migrate) shift; cmd_migrate "${1:-}" ;;
  -h|--help) usage ;;
  *)
    if [[ "$cmd" =~ ^https?:// ]] || [ -f "$cmd" ]; then
      cmd_install "$@"
    else
      usage
    fi
    ;;
esac
