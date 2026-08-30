#!/bin/bash
#
# appimage — tiny AppImage manager.
#
# Subcommands:
#   (none)                       list apps — installed and available (default)
#   install <url|path|name>      download / copy & register an AppImage
#   install -i                   pick apps to install from the catalog
#   list / ls                    show every app: installed ones plus what the
#                                catalog offers but isn't installed yet
#   info <name-or-path>          crack open an AppImage and print what's inside
#   update <name> | --all | -i   re-check GitHub source and upgrade if newer
#   remove <name>                delete binary, wrapper, desktop entry, metadata
#   wrap <name> | --all          regenerate the ~/bin/<name> wrapper from metadata
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

# --- update output mode ------------------------------------------------------
# `update --all` used to narrate two lines per app — a "Resolving ..." line and
# a "[name] ..." line — which buried the three apps that actually needed
# attention under twelve that did not. In row mode the chatter is suppressed and
# each app gets one aligned line plus a summary. A single `update <name>` keeps
# the original verbose form, where the detail is the point.
UPDATE_ROWS=false     # true => one aligned row per app, and count the outcomes
RESOLVE_QUIET=false   # true => resolvers do not announce what they are fetching
RESOLVE_ERR_FILE=""   # set => resolvers write the failure reason here, not stderr
NAME_W=18             # name column width, sized to the longest name per run
_UPD_OK=0; _UPD_NEW=0; _UPD_SKIP=0; _UPD_FAIL=0

# Report one app's outcome. Row mode prints a table line and bumps a counter;
# otherwise the original message goes out on the stream it always used —
# results on stdout, problems on stderr.
upd_emit() {
  local kind="$1" name="$2" detail="$3" verbose="$4" mark
  case "$kind" in
    ok)   mark="✓"; _UPD_OK=$((_UPD_OK + 1)) ;;
    new)  mark="↑"; _UPD_NEW=$((_UPD_NEW + 1)) ;;
    skip) mark="·"; _UPD_SKIP=$((_UPD_SKIP + 1)) ;;
    *)    mark="✗"; _UPD_FAIL=$((_UPD_FAIL + 1)) ;;
  esac
  if [ "$UPDATE_ROWS" = "true" ]; then
    printf '  %s %-*s %s\n' "$mark" "$NAME_W" "$name" "$detail"
  else
    case "$kind" in
      ok|new) printf '%s\n' "$verbose" ;;
      *)      printf '%s\n' "$verbose" >&2 ;;
    esac
  fi
}

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
  $PROG                              list apps — installed and available (default)
  $PROG <command> [options]

COMMANDS
  list, ls                           list every app: installed ones, plus the
                                     catalog apps not installed yet
  install [options] <url|path|name>  install an AppImage and register it
  install -i                         pick apps to install from the catalog
  update <name>                      update one app if a newer release exists
  update --all                       update every managed app
  update -i                          pick which apps to update
  info <name|path>                   inspect a managed app or AppImage file
  remove <name>                      uninstall an app (binary, launcher, metadata)
  wrap <name> | --all                regenerate the ~/bin/<name> wrapper script
  migrate [<name>]                   adopt pre-existing ~/bin/<name> AppImages

INSTALL OPTIONS
  --name <name>       override the auto-derived app name
  --guard <name>      run appimage-guards/<name>.sh before install/update;
                      a non-zero exit skips the app (e.g. 'personal-only'
                      blocks corp hosts). Recorded in metadata, so it re-runs
                      on every update.
  --unofficial        mark as a community/3rd-party build (shown in list)
  --cli               the app is a CLI as well as a GUI (e.g. paseo): run it in
                      the foreground with output on the terminal when given
                      arguments, and detach only when launched bare
  --no-sandbox        replay the sandbox switches from the app's own .desktop
                      (e.g. Paseo's "Exec=AppRun --no-sandbox %U") in the
                      wrapper. Only for apps that cannot start without them —
                      it turns Chromium's sandbox off. Off by default.
  -i, --interactive   choose apps interactively instead of naming one

NOTES
  A bare URL or .AppImage path implies 'install'. A bare name that matches a
  not-installed app in $PROG list is installed from its recorded source.
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

# A token for api.github.com, or empty if there is none.
#
# Unauthenticated callers get 60 requests/hour per IP. `update --all` spends one
# per GitHub-hosted app — 13 here — so two or three runs in an hour exhaust the
# quota and every app fails at once, which reads as "sometimes it works,
# sometimes it doesn't". `gh` is usually logged in already, and borrowing its
# token lifts the ceiling to 5000/hour, so the limit stops being reachable.
#
# Deliberately not cached: every caller runs inside a $(...) subshell, so a cache
# would not survive to the next app anyway. Reading gh's token is a local file
# read, and 13 of those are free next to 13 network round trips.
github_token() {
  local t=""
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    t="$GITHUB_TOKEN"
  elif command -v gh >/dev/null 2>&1; then
    t=$(gh auth token 2>/dev/null || true)
    # `gh auth token` only exists from gh 2.17. Older builds (Ubuntu ships 2.4)
    # print "unknown command ..." followed by a usage block — on stdout, not
    # stderr — so 2>/dev/null does not hide it and the exit status is not
    # enough. Judge it by shape: a real token is one whitespace-free word.
    case "$t" in ""|*[[:space:]]*) t="" ;; esac
  fi
  # Nothing usable from the CLI: read the token gh already stores.
  # One awk, not a sed|head|tr pipeline: under `set -o pipefail` head can close
  # the pipe first, sed dies of SIGPIPE, and the whole assignment fails.
  if [ -z "$t" ] && [ -f "$HOME/.config/gh/hosts.yml" ]; then
    t=$(awk '/^[[:space:]]*oauth_token:/ {
               sub(/^[[:space:]]*oauth_token:[[:space:]]*/, "")
               gsub(/["'\''\r]/, "")
               print; exit
             }' "$HOME/.config/gh/hosts.yml" 2>/dev/null || true)
  fi
  # Never let anything with whitespace through. A failed lookup that returns an
  # error message would otherwise be spliced into the Authorization header and
  # break every request outright — which is worse than sending none at all.
  case "$t" in
    ""|*[[:space:]]*) return 0 ;;
  esac
  printf '%s' "$t"
}

# Fetch a release blob from the GitHub API. An empty tag means "latest".
#
# On failure the reason goes to RESOLVE_ERR_FILE when the caller set one, so a
# batch run can put it in the app's own row instead of printing a loose line
# above it; otherwise it goes to stderr as before.
github_release_json() {
  local repo="$1" tag="${2:-}" api token
  if [ -n "$tag" ]; then
    api="https://api.github.com/repos/${repo}/releases/tags/${tag}"
  else
    api="https://api.github.com/repos/${repo}/releases/latest"
  fi
  local hdrs=(-H "Accept: application/vnd.github+json")
  token=$(github_token)
  [ -n "$token" ] && hdrs+=(-H "Authorization: Bearer ${token}")

  local dir code remaining reset msg
  dir=$(mktemp -d)
  code=$(curl -sL -o "$dir/body" -D "$dir/hdr" -w '%{http_code}' "${hdrs[@]}" "$api" 2>/dev/null) || code="000"

  if [ "$code" = "200" ]; then
    cat "$dir/body"
    rm -rf "$dir"
    return 0
  fi

  remaining=$(grep -i '^x-ratelimit-remaining:' "$dir/hdr" 2>/dev/null | tr -d '\r' | awk '{print $2}')
  reset=$(grep -i '^x-ratelimit-reset:' "$dir/hdr" 2>/dev/null | tr -d '\r' | awk '{print $2}')
  rm -rf "$dir"

  if { [ "$code" = "403" ] || [ "$code" = "429" ]; } && [ "${remaining:-1}" = "0" ]; then
    msg="GitHub rate limit reached"
    if [ -n "$reset" ]; then
      msg="$msg, resets in $(( (reset - $(date +%s) + 59) / 60 ))m"
    fi
    [ -n "$token" ] || msg="$msg (unauthenticated: 60/h — run 'gh auth login' for 5000/h)"
  elif [ "$code" = "000" ]; then
    msg="could not reach api.github.com"
  else
    msg="GitHub API returned HTTP $code"
  fi

  if [ -n "${RESOLVE_ERR_FILE:-}" ]; then
    printf '%s' "$msg" > "$RESOLVE_ERR_FILE"
  else
    echo "$msg: $api" >&2
  fi
  return 1
}

resolve_github() {
  local url="$1" owner repo tag
  if [[ "$url" =~ ^https?://github\.com/([^/]+)/([^/?#]+)(/releases(/tag/([^/?#]+)|/latest)?)?/?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]%.git}"
    tag="${BASH_REMATCH[5]:-}"
    [ "$RESOLVE_QUIET" = "true" ] || echo "Resolving GitHub release: ${owner}/${repo}${tag:+ @ $tag}" >&2
    local json
    json=$(github_release_json "${owner}/${repo}" "$tag") || return 1
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

# Resolve a *templated* source URL to "ASSET_URL<TAB>TAG<TAB>RELEASE_NAME".
#
# Some projects tag releases on GitHub but host the AppImage on their own site,
# so there is no release asset to discover — the download URL has to be built
# from the version. A templated source is that URL with placeholders, plus a
# "#github=OWNER/REPO" fragment naming the repo the version comes from:
#
#   https://sonic-pi.net/files/releases/{tag}/Sonic-Pi-for-Linux-{arch_short}-{tag}.AppImage#github=sonic-pi-net/sonic-pi
#
# Placeholders: {tag} (v5.0.0)  {version} (5.0.0)
#               {arch} (x86_64 / aarch64)  {arch_short} (x64 / arm64)
#
# The template — not the resolved URL — is what lands in metadata, so `update`
# re-resolves it later and picks up new releases on its own.
resolve_templated() {
  local url="$1" template repo json tag release_name arch arch_short out
  template="${url%%#github=*}"
  repo="${url##*#github=}"
  [ -n "$template" ] && [ -n "$repo" ] || { echo "Malformed templated source: $url" >&2; return 1; }

  [ "$RESOLVE_QUIET" = "true" ] || echo "Resolving GitHub release: ${repo} (templated download URL)" >&2
  json=$(github_release_json "$repo") || return 1
  tag=$(jq -r '.tag_name // ""' <<<"$json")
  release_name=$(jq -r '.name // ""' <<<"$json")
  [ -n "$tag" ] || { echo "No tag_name in latest release of $repo" >&2; return 1; }

  case "$(uname -m)" in
    x86_64|amd64)  arch="x86_64";      arch_short="x64" ;;
    aarch64|arm64) arch="aarch64";     arch_short="arm64" ;;
    *)             arch="$(uname -m)"; arch_short="$(uname -m)" ;;
  esac

  out="$template"
  out="${out//\{tag\}/$tag}"
  out="${out//\{version\}/${tag#v}}"
  out="${out//\{arch\}/$arch}"
  out="${out//\{arch_short\}/$arch_short}"
  printf '%s\t%s\t%s\n' "$out" "$tag" "$release_name"
}

# Resolve a "latest" URL that 302s to the current build.
#
# Some vendors are not on GitHub at all, so there is no release to query and no
# version to interpolate — but they do publish a stable URL that redirects to
# whatever the newest asset is. LM Studio is the case here:
#
#   https://lmstudio.ai/download/latest/linux/x64?format=AppImage#latest
#     -> https://installers.lmstudio.ai/linux/x64/0.4.23-1/LM-Studio-0.4.23-1-x64.AppImage
#
# Mark such a source with a trailing "#latest". We follow the redirect, take the
# final URL as the asset, and read the version out of its filename — so the
# version comes from where the redirect lands rather than from a release API.
#
# The pinned URL this replaces could never update: with the version baked into
# the path, re-resolving it just fetched the same build forever.
#
# Caveat: this can only see a new version when the redirect target's filename
# changes. A vendor who serves a constant name (always "App-latest.AppImage")
# would look permanently up-to-date.
resolve_latest_redirect() {
  local url="${1%\#latest}" final base version
  [ "$RESOLVE_QUIET" = "true" ] || echo "Resolving latest-redirect source: $url" >&2
  final=$(curl -sIL --max-time 60 -o /dev/null -w '%{url_effective}' "$url") \
    || { echo "Could not follow redirects for: $url" >&2; return 1; }
  [ -n "$final" ] || { echo "No redirect target for: $url" >&2; return 1; }

  base="${final%%\?*}"     # drop any query string
  base="${base##*/}"       # basename
  case "$base" in
    *.AppImage|*.appimage|*.APPIMAGE) ;;
    *) echo "Redirect target is not an .AppImage: $final" >&2; return 1 ;;
  esac

  # "LM-Studio-0.4.23-1-x64.AppImage" -> "0.4.23-1". Fall back to the whole
  # filename so a rename still reads as a new version rather than as "same".
  version=$(printf '%s' "$base" | grep -oE '[0-9]+(\.[0-9]+)+(-[0-9]+)?' | head -n1)

  # Empty release name on purpose. There is no human-facing release title to
  # report here — the only other candidate is the asset filename, and letting
  # that through means `list` and `update` show a row reading
  # "LM-Studio-0.4.23-1-x64.AppImage" where every other app shows a version.
  # Leaving it blank makes both fall back to the tag. It also takes the
  # release-name half of update's comparison out of play, which is right: for
  # these sources the tag is the only thing that carries the version.
  printf '%s\t%s\t%s\n' "$final" "${version:-$base}" ""
}

# Resolve any tracked source (GitHub release page, templated download URL, or a
# latest-redirect URL).
resolve_source() {
  case "$1" in
    *'#github='*) resolve_templated "$1" ;;
    *'#latest')   resolve_latest_redirect "$1" ;;
    *)            resolve_github "$1" ;;
  esac
}

# Can this source be re-resolved to find a newer build? Update used to ask "is
# there a github_repo?", which quietly wrote off every non-GitHub vendor. The
# question it actually wants to ask is this one.
source_is_resolvable() {
  case "${1:-}" in
    "")           return 1 ;;
    *'#github='*) return 0 ;;
    *'#latest')   return 0 ;;
    *)            [ -n "$(github_repo_from_url "$1" || true)" ] ;;
  esac
}

github_repo_from_url() {
  local url="$1"
  # Templated sources carry their repo in the "#github=OWNER/REPO" fragment.
  if [[ "$url" == *'#github='* ]]; then
    echo "${url##*#github=}"
    return
  fi
  if [[ "$url" =~ ^https?://github\.com/([^/]+)/([^/?#]+) ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
  fi
}

# What to show as an app's version. Release names are free text upstream: most
# are useful ("Paseo v0.6.1"), but some are just the asset filename
# ("LM-Studio-0.4.23-1-x64.AppImage"), which is noise in a table next to a
# column of tidy versions. Fall back to the tag whenever the name looks like a
# filename rather than a label.
version_label() {
  local release_name="${1:-}" tag="${2:-}"
  case "$release_name" in
    ""|*.AppImage|*.appimage|*.APPIMAGE) printf '%s' "${tag:-?}" ;;
    *)                                   printf '%s' "$release_name" ;;
  esac
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
  local name="$1" target="$2" exec_args="${3:-}" cli="${4:-false}"
  # Flags the vendor's own .desktop insists on. Paseo ships
  # "Exec=AppRun --no-sandbox %U" because its Electron 41 / Chrome 146 build
  # cannot bring up the namespace sandbox here, and the setuid fallback can
  # never work from a squashfs AppImage. Dropping these on the floor is how a
  # perfectly good AppImage turns into a crash on launch, so they go ahead of
  # whatever the caller passed.
  local pre="${exec_args:+ $exec_args}"

  # These are GUI apps; launched from a terminal they spew Electron/Chromium
  # chatter to stdout/stderr. Redirect that to a per-app log (truncated each
  # launch so it stays small) to keep the shell clean — `tail` it to debug.
  #
  # They also have to be detached. A distro package's `code`/`discord` launcher
  # is a thin CLI that hands off to the real GUI process and exits, so the
  # prompt comes straight back. An AppImage has no such split: AppRun `exec`s
  # the GUI binary itself, so running it inline pins the app to the terminal —
  # it blocks until you quit, and closing the terminal kills it. setsid puts it
  # in its own session so neither happens.
  #
  # Exception: --wait/-w callers (e.g. `code --wait` as $EDITOR, or as git's
  # core.editor) depend on the process blocking until the file is closed, so
  # those stay in the foreground.
  #
  # Hybrid apps (--cli) invert the default: one binary is both a terminal
  # program and the desktop app, so detaching has to be decided per call.
  if [ "$cli" = "true" ]; then
    # `paseo status` is a CLI whose output the caller is waiting to read —
    # detaching it into a log file makes it look like it printed nothing. Bare
    # `paseo` is the Electron GUI and still has to detach. Tell them apart by
    # the arguments: none at all, or a single <scheme>:// URL (the desktop
    # entry's %U handing over a paseo:// link), means GUI; anything else is CLI.
    cat > "$BIN_DIR/$name" <<EOF
#!/bin/sh
gui=0
case \$# in
  0) gui=1 ;;
  1) case "\$1" in *://*) gui=1 ;; esac ;;
esac
if [ "\$gui" = 0 ]; then
  exec "$target"$pre "\$@"
fi
log_dir="\${HOME}/bin/.appimage/logs"
mkdir -p "\$log_dir"
setsid "$target"$pre "\$@" >"\$log_dir/$name.log" 2>&1 &
EOF
  else
    cat > "$BIN_DIR/$name" <<EOF
#!/bin/sh
log_dir="\${HOME}/bin/.appimage/logs"
mkdir -p "\$log_dir"
for arg in "\$@"; do
  case "\$arg" in
    -w|--wait) exec "$target"$pre "\$@" >"\$log_dir/$name.log" 2>&1 ;;
  esac
done
setsid "$target"$pre "\$@" >"\$log_dir/$name.log" 2>&1 &
EOF
  fi
  chmod +x "$BIN_DIR/$name"
  ensure_apparmor_profile "$name"
}

# Some Electron AppImages cannot launch at all under Ubuntu's
# kernel.apparmor_restrict_unprivileged_userns=1 without a profile granting
# `userns` — Chromium's sandbox setup aborts. See apps/apparmor/ for the detail.
#
# Best-effort: this needs sudo, and install/wrap runs plenty of places where no
# password can be entered. A failure here must never fail the AppImage install —
# `uq` calls the same script and will apply it properly next run.
ensure_apparmor_profile() {
  local name="$1"
  local installer="$HOME/dotfiles/scripts/install/apparmor-appimage.sh"
  [ -x "$installer" ] || return 0
  [ -f "$HOME/dotfiles/apps/apparmor/$name-appimage" ] || return 0
  "$installer" "$name-appimage" || true
}

# Find the .desktop entry at the root of an extracted AppImage.
#
# `-name '*.desktop'` alone is not enough. An app whose reverse-DNS ID ends in
# ".desktop" — opencode ships ai.opencode.desktop — gives its *binary* a name
# the glob matches, and it sorts ahead of the real ai.opencode.desktop.desktop.
# Taking the first hit blindly once copied a 216MB executable into
# ~/.local/share/applications/. Require the [Desktop Entry] group header, which
# only a real entry has; the read is byte-capped so a huge binary stays cheap.
find_desktop_entry() {
  local sq="$1" cand
  while IFS= read -r cand; do
    [ -n "$cand" ] || continue
    if head -c 1024 -- "$cand" 2>/dev/null | grep -qa '^\[Desktop Entry\]'; then
      printf '%s' "$cand"
      return 0
    fi
  done < <(find -L "$sq" -maxdepth 1 -name '*.desktop' -type f 2>/dev/null | sort)
  return 1
}

# Pull the *launch-critical* flags out of an embedded entry's Exec line:
#   "Exec=AppRun --no-sandbox %U"  ->  "--no-sandbox"
#
# Only sandbox switches are taken, because only they decide whether the app
# starts at all. Paseo ships "--no-sandbox" since its Electron 41 / Chrome 146
# build cannot bring up the namespace sandbox here and the setuid fallback can
# never work from a squashfs AppImage; without the flag it dies on a /dev/shm
# error before painting a window.
#
# Everything else in the vendor's Exec is deliberately ignored. VS Code's entry
# is "Exec=code --unity-launch %F", and --unity-launch is a hint that only makes
# sense when the launcher starts the app — replaying it from ~/bin/code would
# also apply it to `code --wait` as $EDITOR, which is not what it means. Those
# flags stay a property of the .desktop file, not of the wrapper.
#
# Extracting is not the same as using: only apps that opted in (--no-sandbox)
# get these replayed. Half the Electron AppImages here ship "--no-sandbox" in
# their .desktop and run fine sandboxed anyway, and turning Chromium's sandbox
# off for all of them — when apps/apparmor/ exists precisely to keep it on —
# would be a silent downgrade nobody asked for. Opt in per app instead.
extract_exec_args() {
  local desktop="$1" line tok out=""
  line=$(grep -m1 '^Exec=' "$desktop" 2>/dev/null | sed 's/^Exec=//') || return 0
  # Drop the leading binary token (AppRun / the app name, possibly quoted).
  line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*("[^"]*"|[^[:space:]]+)[[:space:]]*//')
  for tok in $line; do
    case "$tok" in
      --*sandbox|--*sandbox=*) out="${out:+$out }$tok" ;;
    esac
  done
  printf '%s' "$out"
}

# Sets EXEC_ARGS as a side effect — the flags the wrapper has to replay. The
# caller reads it after this returns, so write_wrapper must run *after* this.
install_desktop_entry() {
  local name="$1" appimage_path="$2"
  EXEC_ARGS=""
  local extract_root
  extract_root=$(mktmp)
  ( cd "$extract_root" && "$appimage_path" --appimage-extract >/dev/null 2>&1 ) || return 0
  # squashfs-root may be a symlink (e.g. sharun-based AppImages) — -L follows it.
  local sq="$extract_root/squashfs-root"
  [ -e "$sq" ] || return 0

  local desktop_src
  desktop_src=$(find_desktop_entry "$sq") || return 0
  [ -n "$desktop_src" ] || return 0

  EXEC_ARGS=$(extract_exec_args "$desktop_src")

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
  local exec_args="${13:-}" cli="${14:-false}" no_sandbox="${15:-false}"
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
    --arg exec_args "$exec_args" \
    --argjson cli "$cli" \
    --argjson no_sandbox "$no_sandbox" \
    --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{name:$name, source_url:$source_url, asset_url:$asset_url, tag:$tag,
      release_name:$release_name, github_repo:$github_repo, filename:$filename,
      sha256:$sha256, target:$target, origin:$origin, unofficial:$unofficial,
      guard:$guard, exec_args:$exec_args, cli:$cli, no_sandbox:$no_sandbox,
      installed_at:$installed_at}' \
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

# Emit the catalog as "name<TAB>url<TAB>guard<TAB>description[<TAB>flags]" rows,
# skipping comments and blank lines. The catalog is the menu behind `install -i`
# and lets `install <name>` resolve a known app to its source.
catalog_rows() {
  [ -f "$CATALOG_FILE" ] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$CATALOG_FILE" || true
}

# Look up a catalog entry by name; prints "url<TAB>guard<TAB>flags", returns 0 on
# a hit. `flags` is the optional trailing column — kept last so the many
# 4-column rows that predate it still parse, landing "-" in `flags`.
#
# Empty fields are emitted as "-", never as nothing. Tab counts as IFS
# whitespace, so a caller's `IFS=$'\t' read` collapses runs of tabs into one
# separator: printing an empty guard here would shift `flags` left into
# `c_guard` and have the reader try to run "cli" as a guard script. Callers
# translate "-" back to empty after splitting.
catalog_lookup() {
  local want="$1" name url guard desc flags
  while IFS=$'\t' read -r name url guard desc flags; do
    [ "$name" = "$want" ] || continue
    printf '%s\t%s\t%s' "$url" "${guard:--}" "${flags:--}"
    return 0
  done < <(catalog_rows)
  return 1
}

# Undo the "-" placeholder catalog_lookup emits for an absent value.
catalog_unset() {
  case "${1:-}" in
    -|"") printf '' ;;
    *)    printf '%s' "$1" ;;
  esac
}

# Does a catalog flags field carry `want`? Flags are comma-separated (e.g. "cli").
catalog_has_flag() {
  case ",${1:-}," in
    *",$2,"*) return 0 ;;
  esac
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
  local skip_guard="false" cli="false" no_sandbox="false"
  while [ $# -gt 0 ]; do
    case "$1" in
      --unofficial) unofficial="true"; shift ;;
      --cli) cli="true"; shift ;;
      --no-sandbox) no_sandbox="true"; shift ;;
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
    rows=$(catalog_rows | while IFS=$'\t' read -r n u g d fl; do
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
    local hit c_url c_guard c_flags
    if hit=$(catalog_lookup "$arg"); then
      IFS=$'\t' read -r c_url c_guard c_flags <<<"$hit"
      c_guard=$(catalog_unset "$c_guard"); c_flags=$(catalog_unset "$c_flags")
      [ -n "$name_override" ] || name_override="$arg"
      [ -n "$guard" ] || guard="$c_guard"
      catalog_has_flag "$c_flags" cli && cli="true"
      catalog_has_flag "$c_flags" no-sandbox && no_sandbox="true"
      arg="$c_url"
    else
      echo "Unknown app '$arg' (not a URL, path, or catalog entry)." >&2
      echo "Try: $PROG catalog" >&2
      exit 1
    fi
  fi

  local source_url="$arg" asset_url="" tag="" github_repo="" release_name=""
  github_repo=$(github_repo_from_url "$arg" || true)

  if source_is_resolvable "$arg"; then
    local resolved
    resolved=$(resolve_source "$arg") || exit 1
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

  # Extract first: install_desktop_entry sets EXEC_ARGS, which the wrapper needs.
  EXEC_ARGS=""
  install_desktop_entry "$name" "$target" || true
  [ "$no_sandbox" = "true" ] || EXEC_ARGS=""
  write_wrapper "$name" "$target" "$EXEC_ARGS" "$cli"
  write_metadata "$name" "$source_url" "$asset_url" "$tag" "$github_repo" \
                 "$filename" "$sha256" "$target" "install" "$unofficial" \
                 "$release_name" "$guard" "$EXEC_ARGS" "$cli" "$no_sandbox"

  echo "Installed: $name"
  echo "  Binary:   $target"
  echo "  Wrapper:  $BIN_DIR/$name"
  if [ -n "$tag" ]; then echo "  Version:  $tag"; fi
  if [ -n "$guard" ]; then echo "  Guard:    $guard"; fi
  if [ -n "$EXEC_ARGS" ]; then echo "  Args:     $EXEC_ARGS (from the app's own .desktop)"; fi
  if [ "$cli" = "true" ]; then echo "  Mode:     hybrid CLI/GUI"; fi
  if [ -f "$APP_DIR/$name.desktop" ]; then echo "  Launcher: $APP_DIR/$name.desktop"; fi
}

# --- list --------------------------------------------------------------------

# Join flag words into the "(unofficial, personal-only)" suffix hung off SOURCE.
# Empty in, empty out — so the common no-flags row stays clean.
flag_suffix() {
  local out="" f
  for f in "$@"; do
    [ -n "$f" ] || continue
    out="${out:+$out, }$f"
  done
  [ -n "$out" ] && printf ' (%s)' "$out"
  return 0
}

# One table for everything: apps we manage (from metadata) followed by the
# catalog apps not installed yet. There is no separate `catalog` command — an
# app you could install and one you already did belong in the same list, and
# the STATUS column is what tells them apart.
cmd_list() {
  mkdir -p "$META_DIR"
  local out
  out=$({
    local f name tag source origin guard flags
    for f in "$META_DIR"/*.json; do
      [ -e "$f" ] || continue
      name=$(jq -r '.name' "$f")
      tag=$(jq -r 'if (.tag // "") == "" then "-" else .tag end' "$f")
      origin=$(jq -r '.origin // "install"' "$f")
      guard=$(jq -r '.guard // ""' "$f")
      source=$(jq -r '
        if (.github_repo // "") != "" then .github_repo
        elif (.source_url // "") != "" then .source_url
        else "-" end' "$f")
      flags=$(flag_suffix \
        "$([ "$(jq -r '.unofficial // false' "$f")" = "true" ] && echo unofficial)" \
        "$([ "$origin" = "migrated" ] && echo migrated)" \
        "$guard")
      printf '%s\t%s\t%s%s\tinstalled %s\n' \
        "$name" "$tag" "$source" "$flags" \
        "$(relative_time "$(jq -r '.installed_at' "$f")")"
    done

    # Catalog apps we don't have. Show the GitHub repo rather than the raw
    # source URL so these line up with the installed rows above.
    local url desc repo cflags
    while IFS=$'\t' read -r name url guard desc cflags; do
      [ -n "$name" ] || continue
      [ -f "$META_DIR/$name.json" ] && continue
      [ "$guard" = "-" ] && guard=""
      repo=$(github_repo_from_url "$url" || true)
      printf '%s\t-\t%s%s\tnot installed\n' \
        "$name" "${repo:-$url}" "$(flag_suffix "$guard")"
    done < <(catalog_rows | sort)
  })

  if [ -z "$out" ]; then
    echo "(no AppImages installed, and the catalog is empty: $CATALOG_FILE)" >&2
    return 0
  fi
  { printf 'NAME\tVERSION\tSOURCE\tSTATUS\n'; printf '%s\n' "$out"; } | column -t -s $'\t'
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
      (if ((.release_name // "") | test("\\.appimage$"; "i") | not) and (.release_name // "") != ""
       then .release_name
       elif (.tag // "") != "" then .tag else "-" end) as $ver
      | (if (.github_repo // "") != "" then .github_repo
         elif (.source_url // "") != "" then .source_url else "-" end) as $src
      | "  version      : \($ver)",
        "  tag          : \(if (.tag // "") == "" then "-" else .tag end)",
        "  source       : \($src)\(if .unofficial then "  (unofficial)" else "" end)\(if .origin == "migrated" then "  (migrated)" else "" end)",
        "  guard        : \(if (.guard // "") == "" then "-" else .guard end)",
        "  exec args    : \(if (.exec_args // "") == "" then "-" else .exec_args end)\(if .no_sandbox then "  (sandbox off)" else "" end)",
        "  mode         : \(if .cli then "hybrid CLI/GUI" else "GUI" end)",
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
  desktop=$(find_desktop_entry "$sq" || true)
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

  local source_url github_repo current_tag current_release_name origin unofficial guard cli no_sandbox
  cli=$(jq -r 'if .cli then "true" else "false" end' "$meta")
  no_sandbox=$(jq -r 'if .no_sandbox then "true" else "false" end' "$meta")
  source_url=$(jq -r '.source_url // ""' "$meta")
  github_repo=$(jq -r '.github_repo // ""' "$meta")
  current_tag=$(jq -r '.tag // ""' "$meta")
  current_release_name=$(jq -r '.release_name // ""' "$meta")
  origin=$(jq -r '.origin // "install"' "$meta")
  unofficial=$(jq -r '.unofficial // false' "$meta")
  guard=$(jq -r '.guard // ""' "$meta")

  # Metadata with no tracked source — an app adopted by `migrate`, or installed
  # from a bare .AppImage URL before it was catalogued — can still update if the
  # catalog knows the name. Adopt the catalog's source (and guard) and carry on;
  # the reinstall below writes them into metadata, so this only happens once.
  if ! source_is_resolvable "$source_url"; then
    local hit c_url c_guard c_flags
    if hit=$(catalog_lookup "$name"); then
      IFS=$'\t' read -r c_url c_guard c_flags <<<"$hit"
      c_guard=$(catalog_unset "$c_guard"); c_flags=$(catalog_unset "$c_flags")
      if source_is_resolvable "$c_url"; then
        [ "$UPDATE_ROWS" = "true" ] || echo "[$name] adopting catalog source: $c_url" >&2
        source_url="$c_url"
        github_repo=$(github_repo_from_url "$c_url" || true)
        [ -n "$guard" ] || guard="$c_guard"
        catalog_has_flag "$c_flags" cli && cli="true"
        catalog_has_flag "$c_flags" no-sandbox && no_sandbox="true"
        origin="install"
      fi
    fi
  fi

  if ! source_is_resolvable "$source_url" || [ "$origin" = "migrated" ]; then
    upd_emit skip "$name" "no tracked source" \
      "[$name] no tracked source (re-run: appimage install <url> to enable updates)"
    return 0
  fi

  local resolved new_asset new_tag new_release_name reason=""
  [ -n "${RESOLVE_ERR_FILE:-}" ] && : > "$RESOLVE_ERR_FILE"
  if ! resolved=$(resolve_source "$source_url"); then
    [ -n "${RESOLVE_ERR_FILE:-}" ] && reason=$(cat "$RESOLVE_ERR_FILE" 2>/dev/null || true)
    upd_emit fail "$name" "${reason:-resolve failed}" "[$name] resolve failed"
    return 1
  fi
  if [ -z "$resolved" ]; then
    upd_emit fail "$name" "no asset in latest release" \
      "[$name] no asset found in latest release"
    return 1
  fi
  IFS=$'\t' read -r new_asset new_tag new_release_name <<<"$resolved"

  # Decide if up-to-date. Rolling releases (e.g. tag "latest") keep the same tag
  # across versions, so also compare the release name, which carries the version.
  # Legacy metadata without a release_name falls back to tag-only comparison.
  local same_tag=false same_name=false
  [ -n "$current_tag" ] && [ "$new_tag" = "$current_tag" ] && same_tag=true
  { [ -z "$current_release_name" ] || [ "$new_release_name" = "$current_release_name" ]; } && same_name=true
  local cur_label
  cur_label=$(version_label "$current_release_name" "$current_tag")
  if $same_tag && $same_name; then
    upd_emit ok "$name" "$cur_label" "[$name] up-to-date ($cur_label)"
    return 0
  fi

  # An update is available. Run the guard now (only when there's actually work to
  # do), then reinstall with the guard already cleared so it doesn't prompt twice.
  local new_label
  new_label=$(version_label "$new_release_name" "$new_tag")
  if [ -n "$guard" ]; then
    if ! run_guard "$name" "update" "$cur_label" "$new_label" "$guard"; then
      upd_emit skip "$name" "guard '$guard' declined" \
        "⏭  [$name] guard '$guard' declined — skipping update."
      return 0
    fi
  fi

  # Rolling repos (pkgforge-dev's nightly rebuilds) keep the release name at the
  # upstream app version and put the build stamp in the tag, so both sides of
  # the arrow render as "Antigravity_IDE: 2.5.5" and the row reads as an update
  # to the version it is already on. Fall back to the tags, which are the part
  # that actually differs.
  if [ "$cur_label" = "$new_label" ]; then
    cur_label="${current_tag:-$cur_label}"
    new_label="${new_tag:-$new_label}"
  fi
  upd_emit new "$name" "$cur_label  →  $new_label" "[$name] $cur_label -> $new_label"
  local reinstall_args=()
  [ "$unofficial" = "true" ] && reinstall_args+=(--unofficial)
  [ "$cli" = "true" ] && reinstall_args+=(--cli)
  [ "$no_sandbox" = "true" ] && reinstall_args+=(--no-sandbox)
  [ -n "$guard" ] && reinstall_args+=(--guard "$guard" --skip-guard)
  reinstall_args+=(--name "$name" "$source_url")
  # In row mode the install's own "Asset/Downloading/Installed" block would tear
  # the table apart, so drop its stdout — the row above already says what is
  # happening. curl's progress bar is on stderr and survives, which is the one
  # bit of feedback worth keeping while a few hundred MB come down.
  if [ "$UPDATE_ROWS" = "true" ]; then
    cmd_install "${reinstall_args[@]}" >/dev/null
  else
    cmd_install "${reinstall_args[@]}"
  fi
}

# Update a batch of apps as a table: one row each, then a tally. Sizes the name
# column to the longest name so the versions line up whatever is installed.
update_many() {
  local n total=$#
  [ "$total" -gt 0 ] || { echo "(no managed AppImages)" >&2; return 0; }

  UPDATE_ROWS=true
  RESOLVE_QUIET=true
  # Collect each failure's reason so it lands in that app's row rather than as a
  # loose "GitHub API request failed" line floating above the table.
  RESOLVE_ERR_FILE="$(mktmp)/resolve-err"
  _UPD_OK=0; _UPD_NEW=0; _UPD_SKIP=0; _UPD_FAIL=0
  NAME_W=0
  for n in "$@"; do [ "${#n}" -gt "$NAME_W" ] && NAME_W="${#n}"; done

  printf 'Checking %d managed AppImage%s…\n\n' "$total" "$([ "$total" -eq 1 ] || echo s)"
  for n in "$@"; do cmd_update_one "$n" || true; done

  printf '\n  %d checked · %d updated · %d up to date · %d skipped' \
    "$total" "$_UPD_NEW" "$_UPD_OK" "$_UPD_SKIP"
  [ "$_UPD_FAIL" -gt 0 ] && printf ' · %d failed' "$_UPD_FAIL"
  printf '\n'

  UPDATE_ROWS=false
  RESOLVE_QUIET=false
  RESOLVE_ERR_FILE=""
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
    local picked=()
    while IFS= read -r n; do
      [ -n "$n" ] && picked+=("$n")
    done <<<"$chosen"
    update_many "${picked[@]+"${picked[@]}"}"
    return 0
  fi

  if [ "${1:-}" = "--all" ]; then
    mkdir -p "$META_DIR"
    local f names=()
    for f in "$META_DIR"/*.json; do
      [ -e "$f" ] || continue
      names+=("$(jq -r '.name' "$f")")
    done
    update_many "${names[@]+"${names[@]}"}"
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

# --- wrap --------------------------------------------------------------------

# Regenerate the ~/bin/<name> wrapper and the .desktop launcher for a managed
# app from its metadata. Use after write_wrapper / install_desktop_entry logic
# changes to re-apply them to already-installed apps without a full
# reinstall/download — it re-extracts from the binary already on disk.
cmd_wrap_one() {
  local name="$1"
  local meta="$META_DIR/$name.json"
  [ -f "$meta" ] || { echo "Not managed: $name" >&2; return 1; }
  local target cli no_sandbox
  target=$(jq -r '.target' "$meta")
  cli=$(jq -r 'if .cli then "true" else "false" end' "$meta")
  no_sandbox=$(jq -r 'if .no_sandbox then "true" else "false" end' "$meta")
  if [ ! -f "$target" ]; then
    echo "[$name] binary missing ($target) — skipping" >&2
    return 1
  fi
  # Drop the old entry first: a previously mis-detected one has to go even if
  # re-extraction turns up nothing this time.
  remove_desktop_entry "$name"
  # Re-extract before wrapping: this is what re-applies the vendor's Exec flags
  # to apps installed before appimage.sh started honouring them.
  EXEC_ARGS=""
  install_desktop_entry "$name" "$target" || true
  [ "$no_sandbox" = "true" ] || EXEC_ARGS=""
  write_wrapper "$name" "$target" "$EXEC_ARGS" "$cli"
  # Keep metadata honest about what the wrapper now replays.
  local tmp_meta
  tmp_meta=$(mktemp)
  if jq --arg exec_args "$EXEC_ARGS" '.exec_args = $exec_args' "$meta" > "$tmp_meta"; then
    mv -f -- "$tmp_meta" "$meta"
  else
    rm -f -- "$tmp_meta"
  fi
  if [ -f "$APP_DIR/$name.desktop" ]; then
    echo "Wrapped: $name (wrapper + launcher)"
  else
    echo "Wrapped: $name (wrapper; no .desktop entry inside the AppImage)"
  fi
}

cmd_wrap() {
  if [ "${1:-}" = "--all" ]; then
    mkdir -p "$META_DIR"
    local f found=0
    for f in "$META_DIR"/*.json; do
      [ -e "$f" ] || continue
      found=1
      cmd_wrap_one "$(jq -r '.name' "$f")" || true
    done
    [ "$found" -eq 1 ] || echo "(no managed AppImages)" >&2
  else
    [ -n "${1:-}" ] || usage
    cmd_wrap_one "$1"
  fi
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

  EXEC_ARGS=""
  install_desktop_entry "$name" "$target" || true
  write_wrapper "$name" "$target" "$EXEC_ARGS"

  mkdir -p "$META_DIR"
  jq -n \
    --arg name "$name" \
    --arg filename "$filename" \
    --arg sha256 "$sha256" \
    --arg target "$target" \
    --arg installed_at "$installed_at" \
    --arg exec_args "$EXEC_ARGS" \
    '{name:$name, source_url:"", asset_url:"", tag:"", github_repo:"",
      filename:$filename, sha256:$sha256, target:$target,
      origin:"migrated", exec_args:$exec_args, cli:false,
      installed_at:$installed_at}' \
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

# Bare `appimage` lists apps rather than dumping help.
[ $# -ge 1 ] || { cmd_list; exit 0; }
cmd="$1"
case "$cmd" in
  install)   shift; cmd_install "$@" ;;
  list|ls)   shift; cmd_list ;;
  catalog)   shift; cmd_list ;;   # folded into `list`; kept so muscle memory works
  info)    shift; [ $# -eq 1 ] || usage; cmd_info "$1" ;;
  update)  shift; cmd_update "$@" ;;
  remove)  shift; [ $# -eq 1 ] || usage; cmd_remove "$1" ;;
  wrap)    shift; cmd_wrap "${1:-}" ;;
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
