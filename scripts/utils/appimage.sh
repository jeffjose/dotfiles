#!/bin/bash
#
# appimage — tiny AppImage manager.
#
# Subcommands:
#   (none)                       list managed AppImages (default)
#   install <url|path|name>      download / copy & register an AppImage
#   install -i                   pick apps to install from the catalog
#   list                         show managed AppImages
#   catalog                      show apps available to install
#   info <name-or-path>          crack open an AppImage and print what's inside
#   update <name> | --all | -i   re-check GitHub source and upgrade if newer
#   remove <name>                delete binary, wrapper, desktop entry, metadata
#   migrate [<name>]             adopt pre-existing ~/bin/<name> AppImages
#
# If the first arg looks like a URL, an .AppImage path, or a catalog name,
# `install` is implied.
#
# Layout:
#   ~/bin/<name>                              wrapper script (what you run)
#   ~/bin/.appimage/bin/<name>.AppImage       actual binary
#   ~/bin/.appimage/icons/<name>.<ext>        extracted icon
#   ~/bin/.appimage/meta/<name>.json          metadata (source, tag, sha256, ...)
#   ~/.local/share/applications/<name>.desktop  launcher entry
#   scripts/utils/appimage-guards/<name>.sh   optional per-app install guard
#
# Guards:
#   An app can carry a guard — a hook that decides whether install/update should
#   proceed on this machine (e.g. "personal hosts only"). Pass `--guard <name>`
#   at install time (or drop a script at appimage-guards/<appname>.sh to have it
#   auto-discovered). The guard name is remembered in metadata, so `update` and
#   `update --all` re-run it. Contract: exit 0 => proceed, non-zero => skip.
#
# Jeffrey Jose | 2026-04-18

set -euo pipefail

BIN_DIR="${HOME}/bin"
APPIMAGE_DIR="${BIN_DIR}/.appimage"
APPIMAGE_BIN_DIR="${APPIMAGE_DIR}/bin"
META_DIR="${APPIMAGE_DIR}/meta"
ICON_DIR="${APPIMAGE_DIR}/icons"
APP_DIR="${HOME}/.local/share/applications"

# User-facing program name (this script is invoked via the `appimage` alias).
PROG="appimage"

# Guards and the app catalog live next to this script.
_SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
_SELF_DIR="$(dirname "$_SELF")"
GUARD_DIR="$_SELF_DIR/appimage-guards"
CATALOG_FILE="$_SELF_DIR/appimage-catalog.tsv"

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
$PROG — manage AppImages (install, update, and desktop integration).

USAGE
  $PROG                              list installed AppImages (default)
  $PROG <command> [options]

COMMANDS
  install [options] <url|path|name>  install an AppImage and register it
  install -i                         pick apps to install from the catalog
  update <name>                      update one app if a newer release exists
  update --all                       update every managed app
  update -i                          pick which apps to update
  list                               list installed AppImages
  catalog                            list apps available to install
  info <name|path>                   inspect a managed app or AppImage file
  remove <name>                      uninstall an app (binary, launcher, metadata)
  migrate [<name>]                   adopt pre-existing ~/bin/<name> AppImages

INSTALL OPTIONS
  --name <name>       override the auto-derived app name
  --guard <name>      run appimage-guards/<name>.sh before install/update;
                      a non-zero exit skips the app (e.g. 'personal-only'
                      blocks corp hosts). Recorded in metadata, so it re-runs
                      on every update.
  --unofficial        mark as a community/3rd-party build (shown in list)
  -i, --interactive   choose apps interactively instead of naming one

NOTES
  A bare URL or .AppImage path implies 'install'. A bare name that matches a
  catalog entry ($PROG catalog) is installed from its recorded source.
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
    # Pick the asset for THIS machine's architecture. Some releases ship both
    # arches with names like "anylinux-x86_64" / "anylinux-aarch64" — matching on
    # "linux" alone would grab whichever is listed first, so match the host arch
    # explicitly and, failing that, prefer arch-neutral assets over foreign ones.
    local host_pat foreign_pat
    case "$(uname -m)" in
      x86_64|amd64)  host_pat="x86[_-]?64|amd64"; foreign_pat="aarch64|arm64|armv[0-9]|riscv|ppc64|s390|loong" ;;
      aarch64|arm64) host_pat="aarch64|arm64";    foreign_pat="x86[_-]?64|amd64|i[3-6]86|riscv|ppc64|s390|loong" ;;
      *)             host_pat="$(uname -m)";       foreign_pat="x86[_-]?64|amd64|aarch64|arm64" ;;
    esac
    jq -r --arg hostpat "$host_pat" --arg foreignpat "$foreign_pat" '
      . as $r
      | ([$r.assets[] | select(.name | test("\\.AppImage$"; "i"))]) as $a
      | ($a | map(select(.name | test($hostpat; "i")))) as $host
      | ($a | map(select(.name | test($foreignpat; "i") | not))) as $neutral
      | (($host + $neutral + $a) | .[0].browser_download_url // empty) as $url
      | if ($url == "") then "" else "\($url)\t\($r.tag_name // "")\t\($r.name // "")" end
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
  # These are GUI apps; launched from a terminal they spew Electron/Chromium
  # chatter to stdout/stderr. Redirect that to a per-app log (truncated each
  # launch so it stays small) to keep the shell clean — `tail` it to debug.
  cat > "$BIN_DIR/$name" <<EOF
#!/bin/sh
log_dir="\${HOME}/bin/.appimage/logs"
mkdir -p "\$log_dir"
exec "$target" "\$@" >"\$log_dir/$name.log" 2>&1
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
  awk -v exec_prefix="Exec=$BIN_DIR/$name" -v icon_line="${icon_dst:+Icon=$icon_dst}" '
    /^Exec=/   {
      # Preserve a trailing field code (%u/%U/%f/%F) from the source Exec so
      # URL-scheme handlers (e.g. claude://) and file handlers still receive
      # their argument via xdg-open. Without %u the callback URL is dropped.
      code = ""
      if (match($0, /%[uUfF]/)) code = " " substr($0, RSTART, RLENGTH)
      print exec_prefix code
      next
    }
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
  local unofficial="${10:-false}" release_name="${11:-}" guard="${12:-}"
  mkdir -p "$META_DIR"
  jq -n \
    --arg name "$name" \
    --arg source_url "$source_url" \
    --arg asset_url "$asset_url" \
    --arg tag "$tag" \
    --arg release_name "$release_name" \
    --arg github_repo "$github_repo" \
    --arg filename "$filename" \
    --arg sha256 "$sha256" \
    --arg target "$target" \
    --arg origin "$origin" \
    --argjson unofficial "$unofficial" \
    --arg guard "$guard" \
    --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{name:$name, source_url:$source_url, asset_url:$asset_url, tag:$tag,
      release_name:$release_name, github_repo:$github_repo, filename:$filename,
      sha256:$sha256, target:$target, origin:$origin, unofficial:$unofficial,
      guard:$guard, installed_at:$installed_at}' \
    > "$META_DIR/$name.json"
}

# --- guards ------------------------------------------------------------------

# Turn a guard reference into a script path. A value with a slash is used as a
# literal path; a bare name resolves to appimage-guards/<name>.sh next to us.
resolve_guard_path() {
  local guard="$1"
  case "$guard" in
    */*) printf '%s' "$guard" ;;
    *)   printf '%s' "$GUARD_DIR/$guard.sh" ;;
  esac
}

# Run an app's guard, if any. Returns the guard's exit status: 0 => proceed,
# non-zero => the caller should skip the install/update. A missing guard script
# is treated as "proceed" (with a warning) so a typo never silently blocks work.
# The guard gets context via env vars and may prompt on /dev/tty.
run_guard() {
  local name="$1" action="$2" cur="$3" new="$4" guard="$5"
  [ -n "$guard" ] || return 0
  local gpath
  gpath=$(resolve_guard_path "$guard")
  if [ ! -f "$gpath" ]; then
    echo "⚠️  guard '$guard' not found at $gpath — proceeding without it" >&2
    return 0
  fi
  [ -x "$gpath" ] || chmod +x "$gpath" 2>/dev/null || true
  APPIMAGE_NAME="$name" APPIMAGE_ACTION="$action" \
  APPIMAGE_CUR_VERSION="$cur" APPIMAGE_NEW_VERSION="$new" \
    "$gpath" "$name"
}

# --- catalog -----------------------------------------------------------------

# Emit the catalog as "name<TAB>url<TAB>guard<TAB>description" rows, skipping
# comments and blank lines. The catalog is the menu behind `install -i` and lets
# `install <name>` resolve a known app to its source.
catalog_rows() {
  [ -f "$CATALOG_FILE" ] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$CATALOG_FILE" || true
}

# Look up a catalog entry by name; prints "url<TAB>guard" and returns 0 on a hit.
# A guard of "-" (the catalog's "none" placeholder) is normalized to empty.
catalog_lookup() {
  local want="$1" name url guard desc
  while IFS=$'\t' read -r name url guard desc; do
    [ "$name" = "$want" ] || continue
    [ "$guard" = "-" ] && guard=""
    printf '%s\t%s' "$url" "$guard"
    return 0
  done < <(catalog_rows)
  return 1
}

# --- interactive picker ------------------------------------------------------

# Read "value<TAB>label" rows on stdin and print the chosen values, one per line.
# A checkbox multi-select: SPACE toggles a row's [ ]/[*], ENTER confirms, ESC
# cancels. With preselect "all", every row starts checked (deselect to skip).
# Prints nothing (returns 0) when the selection is empty or cancelled.
#
# Backend, in order of preference (override with APPIMAGE_PICKER=whiptail|fzf|plain):
#   whiptail  literal [ ]/[*] checkboxes (matches the described UX)
#   fzf       inline fuzzy multi-select (marker shows the checked rows)
#   plain     numbered text prompt (no TUI available)
pick_multi() {
  local header="${1:-Select}" preselect="${2:-}"
  local rows
  rows=$(cat)
  [ -n "$rows" ] || return 0

  # Every backend needs a controlling terminal (stdout here is captured by the
  # caller, so a plain [ -t 1 ] test would wrongly report "no tty").
  if ! { true </dev/tty; } 2>/dev/null; then
    echo "$header: no terminal available for interactive selection." >&2
    return 0
  fi

  local picker="${APPIMAGE_PICKER:-auto}"
  if [ "$picker" = "auto" ]; then
    if command -v whiptail >/dev/null 2>&1; then picker="whiptail"
    elif command -v fzf >/dev/null 2>&1; then picker="fzf"
    else picker="plain"; fi
  fi

  case "$picker" in
    whiptail)
      # --notags hides the return-tag column so the label (which already carries
      # the name) isn't shown twice. Selected tags come back on fd2 → swap to fd1.
      local -a wt=()
      local val label status count=0
      status="OFF"; [ "$preselect" = "all" ] && status="ON"
      while IFS=$'\t' read -r val label; do
        [ -n "$val" ] || continue
        wt+=("$val" "$label" "$status")
        count=$((count + 1))
      done <<<"$rows"
      [ "$count" -gt 0 ] || return 0
      local listh="$count"; [ "$listh" -gt 14 ] && listh=14
      local out
      out=$(whiptail --title "appimage · $header" --notags --separate-output \
              --checklist "SPACE toggles  ·  ENTER confirms  ·  ESC cancels" \
              "$((listh + 8))" 74 "$listh" "${wt[@]}" \
              3>&1 1>&2 2>&3 </dev/tty) || return 0
      # With --separate-output, tags are newline-separated and unquoted.
      printf '%s\n' "$out" | sed '/^$/d'
      return 0
      ;;
    fzf)
      local out
      out=$(printf '%s\n' "$rows" \
        | fzf --multi --with-nth=2.. --delimiter=$'\t' \
              --marker='✓' --pointer='▶' --highlight-line \
              --reverse --height=50% --prompt="$header " \
              --bind 'space:toggle' \
              ${preselect:+--bind start:select-all} \
              --header='SPACE/TAB toggle · ENTER confirm · ESC cancel') \
        || out=""
      [ -n "$out" ] || return 0
      printf '%s\n' "$out" | cut -f1
      return 0
      ;;
    *)
      # Numbered text prompt.
      local -a vals=()
      local val label i=1
      while IFS=$'\t' read -r val label; do
        vals+=("$val")
        printf '  %2d) %s\n' "$i" "$label" >&2
        i=$((i + 1))
      done <<<"$rows"
      local reply=""
      if [ "$preselect" = "all" ]; then
        printf '%s — numbers to DESELECT (space/comma-separated), or ENTER to keep all: ' "$header" >&2
        read -r reply </dev/tty 2>/dev/null || reply=""
        if [ -z "$reply" ]; then printf '%s\n' "${vals[@]}"; return 0; fi
        if [ "$reply" = "none" ]; then return 0; fi
        local -A drop=()
        local tok
        for tok in ${reply//,/ }; do
          case "$tok" in *[!0-9]*) continue ;; esac
          drop[$tok]=1
        done
        for i in "${!vals[@]}"; do
          [ -n "${drop[$((i + 1))]:-}" ] || printf '%s\n' "${vals[$i]}"
        done
        return 0
      fi
      printf '%s — numbers to select (space/comma-separated), or "all": ' "$header" >&2
      read -r reply </dev/tty 2>/dev/null || reply=""
      [ -n "$reply" ] || return 0
      if [ "$reply" = "all" ]; then printf '%s\n' "${vals[@]}"; return 0; fi
      local tok
      for tok in ${reply//,/ }; do
        case "$tok" in *[!0-9]*) continue ;; esac
        if [ "$tok" -ge 1 ] 2>/dev/null && [ "$tok" -le "${#vals[@]}" ]; then
          printf '%s\n' "${vals[$((tok - 1))]}"
        fi
      done
      ;;
  esac
}

# --- install -----------------------------------------------------------------

cmd_install() {
  local arg="" unofficial="false" name_override="" guard="" interactive="false"
  local skip_guard="false"
  while [ $# -gt 0 ]; do
    case "$1" in
      --unofficial) unofficial="true"; shift ;;
      --name) name_override="${2:-}"; shift 2 ;;
      --guard) guard="${2:-}"; shift 2 ;;
      --skip-guard) skip_guard="true"; shift ;;   # internal: guard already ran
      -i|--interactive) interactive="true"; shift ;;
      -*) echo "Unknown option: $1" >&2; exit 1 ;;
      *) arg="$1"; shift ;;
    esac
  done

  # Interactive: pick apps from the catalog, then install each by name. The menu
  # shows a [x]/[ ] install marker and the installed version (no descriptions).
  if [ "$interactive" = "true" ]; then
    local rows chosen sel
    rows=$(catalog_rows | while IFS=$'\t' read -r n u g d; do
      [ -n "$n" ] || continue
      if [ -f "$META_DIR/$n.json" ]; then
        ver=$(jq -r '.tag // .release_name // "?"' "$META_DIR/$n.json")
        printf '%s\t%-20s installed %s\n' "$n" "$n" "$ver"
      else
        printf '%s\t%-20s not installed\n' "$n" "$n"
      fi
    done)
    [ -n "$rows" ] || { echo "Catalog is empty ($CATALOG_FILE)." >&2; return 0; }
    chosen=$(printf '%s\n' "$rows" | pick_multi "Install")
    [ -n "$chosen" ] || { echo "Nothing selected." >&2; return 0; }
    while IFS= read -r sel; do
      [ -n "$sel" ] || continue
      echo "── $sel ──"
      cmd_install "$sel" || true
    done <<<"$chosen"
    return 0
  fi

  [ -n "$arg" ] || usage
  mkdir -p "$BIN_DIR" "$APPIMAGE_BIN_DIR"

  # A bare token that is neither a URL nor a file is treated as a catalog name.
  if [[ ! "$arg" =~ ^https?:// ]] && [ ! -f "$arg" ]; then
    local hit c_url c_guard
    if hit=$(catalog_lookup "$arg"); then
      IFS=$'\t' read -r c_url c_guard <<<"$hit"
      [ -n "$name_override" ] || name_override="$arg"
      [ -n "$guard" ] || guard="$c_guard"
      arg="$c_url"
    else
      echo "Unknown app '$arg' (not a URL, path, or catalog entry)." >&2
      echo "Try: $PROG catalog" >&2
      exit 1
    fi
  fi

  local source_url="$arg" asset_url="" tag="" github_repo="" release_name=""
  github_repo=$(github_repo_from_url "$arg" || true)

  if [ -n "$github_repo" ]; then
    local resolved
    resolved=$(resolve_github "$arg") || exit 1
    if [ -z "$resolved" ]; then
      echo "No .AppImage asset found in release" >&2
      exit 1
    fi
    IFS=$'\t' read -r asset_url tag release_name <<<"$resolved"
    echo "Asset: $asset_url"
    arg="$asset_url"
  fi

  # Derive the app name up front (before downloading) so a guard can veto the
  # install without paying for the download. --name wins; otherwise derive from
  # the asset/URL/file basename.
  local name basename_hint
  if [ -n "$name_override" ]; then
    name="$name_override"
  else
    basename_hint="${arg%%\?*}"      # drop any query string
    name=$(derive_name "$(basename "$basename_hint")")
  fi
  [ -n "$name" ] || { echo "Could not derive name from: $arg" >&2; exit 1; }

  # Guard: explicit --guard wins; otherwise auto-discover appimage-guards/<name>.sh.
  if [ -z "$guard" ] && [ -f "$GUARD_DIR/$name.sh" ]; then
    guard="$name"
  fi
  if [ "$skip_guard" != "true" ] && [ -n "$guard" ]; then
    if ! run_guard "$name" "install" "" "$tag" "$guard"; then
      echo "⏭  [$name] guard '$guard' declined — skipping." >&2
      return 0
    fi
  fi

  # Fetch the bits now that the guard has approved.
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

  local target="$APPIMAGE_BIN_DIR/$name.AppImage"
  cp -f -- "$src" "$target"
  chmod 0755 "$target"

  local sha256
  sha256=$(sha256sum "$target" | awk '{print $1}')

  rm -f -- "$BIN_DIR/$name"

  write_wrapper "$name" "$target"
  install_desktop_entry "$name" "$target" || true
  write_metadata "$name" "$source_url" "$asset_url" "$tag" "$github_repo" \
                 "$filename" "$sha256" "$target" "install" "$unofficial" \
                 "$release_name" "$guard"

  echo "Installed: $name"
  echo "  Binary:   $target"
  echo "  Wrapper:  $BIN_DIR/$name"
  if [ -n "$tag" ]; then echo "  Version:  $tag"; fi
  if [ -n "$guard" ]; then echo "  Guard:    $guard"; fi
  if [ -f "$APP_DIR/$name.desktop" ]; then echo "  Launcher: $APP_DIR/$name.desktop"; fi
}

# --- catalog listing ---------------------------------------------------------

cmd_catalog() {
  local rows
  rows=$(catalog_rows)
  if [ -z "$rows" ]; then
    echo "(catalog is empty: $CATALOG_FILE)" >&2
    return 0
  fi
  {
    printf 'NAME\tGUARD\tSTATUS\tSOURCE\n'
    local name url guard desc status
    while IFS=$'\t' read -r name url guard desc; do
      [ -n "$name" ] || continue
      if [ -f "$META_DIR/$name.json" ]; then status="installed"; else status="-"; fi
      printf '%s\t%s\t%s\t%s\n' "$name" "${guard:--}" "$status" "$url"
    done <<<"$rows"
  } | column -t -s $'\t'
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

# --- info --------------------------------------------------------------------

# Crack open an AppImage and print a bunch of info: its managed metadata (if any),
# binary facts (size, format magic, arch, live sha256 vs recorded), and the
# .desktop entry embedded *inside* the AppImage. Accepts a managed name or a path.
cmd_info() {
  local arg="${1:-}"
  [ -n "$arg" ] || usage

  local meta="" appimage_path="" name="" meta_sha=""
  if [ -f "$arg" ] && is_appimage "$arg"; then
    appimage_path=$(readlink -f -- "$arg")
    name=$(basename -- "$arg")
  else
    meta="$META_DIR/$arg.json"
    if [ ! -f "$meta" ]; then
      echo "Not a managed name or AppImage path: $arg" >&2
      echo "Try: $PROG list" >&2
      exit 1
    fi
    name="$arg"
    appimage_path=$(jq -r '.target' "$meta")
    meta_sha=$(jq -r '.sha256 // ""' "$meta")
  fi

  echo "=== $name ==="

  # --- managed metadata --------------------------------------------------------
  if [ -n "$meta" ]; then
    echo "Metadata (managed):"
    jq -r --arg bindir "$BIN_DIR" '
      (if (.release_name // "") != "" then .release_name
       elif (.tag // "") != "" then .tag else "-" end) as $ver
      | (if (.github_repo // "") != "" then .github_repo
         elif (.source_url // "") != "" then .source_url else "-" end) as $src
      | "  version      : \($ver)",
        "  tag          : \(if (.tag // "") == "" then "-" else .tag end)",
        "  source       : \($src)\(if .unofficial then "  (unofficial)" else "" end)\(if .origin == "migrated" then "  (migrated)" else "" end)",
        "  guard        : \(if (.guard // "") == "" then "-" else .guard end)",
        "  asset        : \(if (.asset_url // "") == "" then "-" else .asset_url end)",
        "  installed_at : \(.installed_at // "-")",
        "  wrapper      : \($bindir)/\(.name)"
    ' "$meta"
  fi

  # --- binary facts ------------------------------------------------------------
  echo "Binary:"
  echo "  path         : $appimage_path"
  if [ ! -f "$appimage_path" ]; then
    echo "  (binary missing!)"
    return 0
  fi
  echo "  size         : $(du -h -- "$appimage_path" | awk '{print $1}')"

  local magic fmt="unknown"
  magic=$(head -c 12 -- "$appimage_path" 2>/dev/null | od -An -tx1 -N12 | tr -d ' \n')
  case "$magic" in
    7f454c46*414902*) fmt="type-2 AppImage (ELF)" ;;
    7f454c46*414901*) fmt="type-1 AppImage (ELF)" ;;
    7f454c46*)        fmt="ELF (no AppImage magic)" ;;
    2321*)            fmt="shell script (NOT an AppImage!)" ;;
  esac
  echo "  format       : $fmt"

  local arch
  arch=$(file -b -- "$appimage_path" 2>/dev/null | grep -oE 'x86-64|aarch64|arm64|i386' | head -n1)
  [ -n "$arch" ] && echo "  arch         : $arch"

  local live_sha
  live_sha=$(sha256sum -- "$appimage_path" | awk '{print $1}')
  if [ -n "$meta_sha" ] && [ "$live_sha" != "$meta_sha" ]; then
    echo "  sha256       : $live_sha  (⚠ differs from recorded $meta_sha)"
  elif [ -n "$meta_sha" ]; then
    echo "  sha256       : $live_sha  (matches metadata)"
  else
    echo "  sha256       : $live_sha"
  fi

  # --- embedded .desktop (crack open) -----------------------------------------
  if ! is_appimage "$appimage_path"; then
    echo "(cannot introspect internals — not a type-1/2 AppImage)"
    return 0
  fi
  local work sq desktop
  work=$(mktmp)
  ( cd "$work" && timeout 30 "$appimage_path" --appimage-extract '*.desktop' >/dev/null 2>&1 ) || true
  sq="$work/squashfs-root"
  desktop=$(find -L "$sq" -maxdepth 1 -name '*.desktop' -type f 2>/dev/null | head -n1)
  if [ -n "$desktop" ]; then
    echo "Embedded .desktop ($(basename "$desktop")):"
    local k v
    for k in Name GenericName Comment Exec TryExec Icon Categories MimeType StartupWMClass Keywords; do
      v=$(grep -m1 "^$k=" "$desktop" | cut -d= -f2- || true)
      [ -n "$v" ] && printf '  %-14s: %s\n' "$k" "$v"
    done
  else
    echo "(no .desktop found inside AppImage)"
  fi
}

# --- update ------------------------------------------------------------------

cmd_update_one() {
  local name="$1"
  local meta="$META_DIR/$name.json"
  [ -f "$meta" ] || { echo "Not managed: $name" >&2; return 1; }

  local source_url github_repo current_tag current_release_name origin unofficial guard
  source_url=$(jq -r '.source_url // ""' "$meta")
  github_repo=$(jq -r '.github_repo // ""' "$meta")
  current_tag=$(jq -r '.tag // ""' "$meta")
  current_release_name=$(jq -r '.release_name // ""' "$meta")
  origin=$(jq -r '.origin // "install"' "$meta")
  unofficial=$(jq -r '.unofficial // false' "$meta")
  guard=$(jq -r '.guard // ""' "$meta")

  if [ -z "$github_repo" ] || [ "$origin" = "migrated" ]; then
    echo "[$name] no tracked source (re-run: appimage install <url> to enable updates)" >&2
    return 0
  fi

  local resolved new_asset new_tag new_release_name
  resolved=$(resolve_github "$source_url") || { echo "[$name] resolve failed" >&2; return 1; }
  if [ -z "$resolved" ]; then
    echo "[$name] no asset found in latest release" >&2
    return 1
  fi
  IFS=$'\t' read -r new_asset new_tag new_release_name <<<"$resolved"

  # Decide if up-to-date. Rolling releases (e.g. tag "latest") keep the same tag
  # across versions, so also compare the release name, which carries the version.
  # Legacy metadata without a release_name falls back to tag-only comparison.
  local same_tag=false same_name=false
  [ -n "$current_tag" ] && [ "$new_tag" = "$current_tag" ] && same_tag=true
  { [ -z "$current_release_name" ] || [ "$new_release_name" = "$current_release_name" ]; } && same_name=true
  if $same_tag && $same_name; then
    echo "[$name] up-to-date (${current_release_name:-$current_tag})"
    return 0
  fi

  # An update is available. Run the guard now (only when there's actually work to
  # do), then reinstall with the guard already cleared so it doesn't prompt twice.
  if [ -n "$guard" ]; then
    if ! run_guard "$name" "update" "${current_release_name:-$current_tag}" \
                   "${new_release_name:-$new_tag}" "$guard"; then
      echo "⏭  [$name] guard '$guard' declined — skipping update." >&2
      return 0
    fi
  fi

  echo "[$name] ${current_release_name:-${current_tag:-?}} -> ${new_release_name:-${new_tag:-?}}"
  local reinstall_args=()
  [ "$unofficial" = "true" ] && reinstall_args+=(--unofficial)
  [ -n "$guard" ] && reinstall_args+=(--guard "$guard" --skip-guard)
  reinstall_args+=(--name "$name" "$source_url")
  cmd_install "${reinstall_args[@]}"
}

cmd_update() {
  # Interactive: pick which managed apps to update.
  if [ "${1:-}" = "-i" ] || [ "${1:-}" = "--interactive" ]; then
    mkdir -p "$META_DIR"
    local rows chosen n f ver
    rows=$(for f in "$META_DIR"/*.json; do
      [ -e "$f" ] || continue
      n=$(jq -r '.name' "$f")
      ver=$(jq -r '.tag // .release_name // "-"' "$f")
      printf '%s\t%-20s installed %s\n' "$n" "$n" "$ver"
    done)
    [ -n "$rows" ] || { echo "(no managed AppImages)" >&2; return 0; }
    chosen=$(printf '%s\n' "$rows" | pick_multi "Update" "all")
    [ -n "$chosen" ] || { echo "Nothing selected." >&2; return 0; }
    while IFS= read -r n; do
      [ -n "$n" ] && cmd_update_one "$n" || true
    done <<<"$chosen"
    return 0
  fi

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

# Bare `appimage` lists what's installed rather than dumping help.
[ $# -ge 1 ] || { cmd_list; exit 0; }
cmd="$1"
case "$cmd" in
  install) shift; cmd_install "$@" ;;
  list)    shift; cmd_list ;;
  catalog) shift; cmd_catalog ;;
  info)    shift; [ $# -eq 1 ] || usage; cmd_info "$1" ;;
  update)  shift; cmd_update "$@" ;;
  remove)  shift; [ $# -eq 1 ] || usage; cmd_remove "$1" ;;
  migrate) shift; cmd_migrate "${1:-}" ;;
  -h|--help) usage ;;
  *)
    # A URL/path, a known catalog name, or `-i` all imply install.
    if [[ "$cmd" =~ ^https?:// ]] || [ -f "$cmd" ] \
       || [ "$cmd" = "-i" ] || [ "$cmd" = "--interactive" ] \
       || catalog_lookup "$cmd" >/dev/null; then
      cmd_install "$@"
    else
      usage
    fi
    ;;
esac
