# What kind of machine this is, and what a corp machine must not get.
#
# Source this file; it only defines functions. Shared by ./setup, uq, the mise
# update and the appimage `personal-only` guard, so they all agree on what
# "corp" means and on the list of things kept off such a host.

# The mise settings linked into ~/.config/mise/conf.d on a corp host, and the
# appimage catalog whose `personal-only` rows are skipped there.
CORP_MISE_CONFIG="$HOME/dotfiles/apps/mise-corp.toml"
APPIMAGE_CATALOG="$HOME/dotfiles/scripts/utils/appimage-catalog.tsv"

# True on a Google corp host. Be defensive — check multiple sources and
# fail-closed (treat as corp) on any signal of a Google host.
#
# DOTFILES_HOST_KIND=corp|personal overrides the detection, for a machine the
# checks get wrong and for trying the corp path out on a personal one.
is_corp_host() {
  case "${DOTFILES_HOST_KIND:-}" in
    corp) return 0 ;;
    personal) return 1 ;;
  esac

  local fqdn shortname domain

  fqdn=$(hostname -f 2>/dev/null || true)
  [ -z "$fqdn" ] && fqdn=$(hostname --fqdn 2>/dev/null || true)
  [ -z "$fqdn" ] && fqdn=$(hostname 2>/dev/null || true)
  shortname=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
  domain=$(hostname -d 2>/dev/null || true)

  fqdn=$(echo "$fqdn" | tr '[:upper:]' '[:lower:]')
  domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
  shortname=$(echo "$shortname" | tr '[:upper:]' '[:lower:]')

  case "$fqdn" in
    *.google.com|*.corp.google.com|*.c.googlers.com) return 0 ;;
  esac
  case "$domain" in
    google.com|corp.google.com|c.googlers.com) return 0 ;;
  esac

  # Belt and suspenders: glinux-only markers.
  if [ -f /etc/lsb-release ] && grep -qi 'glinux\|goobuntu' /etc/lsb-release 2>/dev/null; then
    return 0
  fi
  if [ -d /google ] || [ -d /usr/local/google ]; then
    return 0
  fi

  return 1
}

# The mise tools a corp host must not install, one per line: the disable_tools
# list in apps/mise-corp.toml, which is the only place they are written down.
corp_blocked_mise_tools() {
  [ -f "$CORP_MISE_CONFIG" ] || return 0
  sed -n '/^[[:space:]]*disable_tools[[:space:]]*=/,/\]/p' "$CORP_MISE_CONFIG" |
    grep -oE '"[^"]+"' | tr -d '"'
}

# The AppImages a corp host must not install, one per line: the catalog rows
# guarded by `personal-only`.
corp_blocked_appimages() {
  [ -f "$APPIMAGE_CATALOG" ] || return 0
  awk -F'\t' '!/^#/ && $3 == "personal-only" {print $1}' "$APPIMAGE_CATALOG"
}
