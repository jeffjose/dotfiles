#!/usr/bin/env -S bash --noprofile
#
# Build GNU screen 5 from source into ~/.local
#
# Ubuntu 22.04 ships screen 4.09, which has no truecolor. Screen 5 is not
# packaged there, so this builds the newest release from ftp.gnu.org into
# ~/.local — no root needed — and `make install` leaves
# ~/.local/bin/screen -> screen-X.Y.Z. ~/bin/scrn picks the newest screen on
# the machine and sets SCREENDIR for v5; /usr/bin/screen stays as it is, for
# sessions started under screen 4.
#
# It is built to read ~/.local/etc/screenrc, not /etc/screenrc: the distro's
# system screenrc is written for screen 4 and screen 5 complains about it on
# every start. Nothing has to be in that file.
#
# Nothing is rebuilt when ~/.local/bin/screen already reports the newest
# version and was built with the options below (a stamp file next to its
# share/screen records them). The tarball's signature must come from Alexander Naumov, screen's
# maintainer, or nothing is built. The build's output goes to a log, whose path
# is printed if it fails; under uq the log sits with that run's step logs.
#
# The ncurses and PAM headers are not installed on these machines (the runtime
# libraries are), and installing them would take root. So when they are
# missing, their -dev packages are fetched with `apt-get download` and unpacked
# with `dpkg -x` into a temporary prefix the build points at. PAM stays enabled.
#
# SCREEN_PREFIX=dir installs somewhere other than ~/.local (for trying it out).
#
# Jeffrey Jose | 2026-10-25
#
set -euo pipefail

source "$HOME/dotfiles/scripts/lib/ui.sh"

PREFIX="${SCREEN_PREFIX:-$HOME/.local}"
MIRROR="https://ftp.gnu.org/gnu/screen"
# Alexander Naumov <alexander_naumov@opensuse.org>, who signs the releases.
SIGNING_KEY="7832918905C6D316DFB54313898D726C87C5AFE3"
KEYSERVER="hkps://keyserver.ubuntu.com"
ARCH_LIB="usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo x86_64-linux-gnu)"

# The configure options beyond --prefix. Changing them rebuilds screen on the
# next run, even at the same version.
CONFIG=(--with-system_screenrc="$PREFIX/etc/screenrc")
STAMP="$PREFIX/share/screen/uq-build"

LOG="${UQ_LOG_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/uq}/screen-detail.log"
mkdir -p "${LOG%/*}"
: >"$LOG"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/screen-build.XXXXXX")
trap 'rm -rf -- "$WORK"' EXIT

# Like update_deb.sh, an update is one line that ends with how long it took:
#     Updating screen 5.0.2 → 5.0.3 (1m 4s)
# The line is left open while the build runs; close_line ends it early, so an
# error that interrupts it starts on a line of its own.
OPEN=0
close_line() {
  [[ $OPEN -eq 0 ]] || echo
  OPEN=0
}

# quietly <command...>: run a command with its output in the log, not on screen.
# If it fails, the end of the log is printed, with its path for the rest.
quietly() {
  local status=0 line
  printf '\n$ %s\n' "$*" >>"$LOG"
  "$@" >>"$LOG" 2>&1 || status=$?
  if [[ $status -ne 0 ]]; then
    close_line
    err "\`$1\` failed (exit $status)"
    while IFS= read -r line; do
      detail "$line" >&2
    done < <(grep -v '^[[:space:]]*$' "$LOG" | tail -n 10)
    detail "${DIM}full output: ${LOG/#$HOME/\~}$RESET" >&2
  fi
  return $status
}

# The newest release on the mirror, from its directory listing.
latest=$(curl -fsSL "$MIRROR/" | grep -oE 'screen-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' |
  sed -E 's/^screen-(.*)\.tar\.gz$/\1/' | sort -uV | tail -n 1) || latest=""
if [[ -z "$latest" ]]; then
  err "couldn't find the latest screen release at $MIRROR/"
  exit 1
fi

# "Screen version 5.0.2 (build on ...)"
current=""
if [[ -x "$PREFIX/bin/screen" ]]; then
  current=$("$PREFIX/bin/screen" -v 2>/dev/null | sed -n 's/^Screen version \([0-9.]*\).*/\1/p') || current=""
fi

build="$latest ${CONFIG[*]}"
if [[ "$current" == "$latest" && "$(cat "$STAMP" 2>/dev/null)" == "$build" ]]; then
  say "$DIM" "Fresh" "${DIM}screen $current$RESET"
  exit 0
fi

started=$(now_us)
if [[ "$current" == "$latest" ]]; then
  printf '%s%12s%s %s' "$GREEN" "Rebuilding" "$RESET" "screen $latest (new build options)"
elif [[ -n "$current" ]]; then
  printf '%s%12s%s %s' "$GREEN" "Updating" "$RESET" "screen $current → $latest"
else
  printf '%s%12s%s %s' "$GREEN" "Installing" "$RESET" "screen $latest"
fi
OPEN=1

# Download and verify.
tarball="screen-$latest.tar.gz"
mkdir -p "$WORK/src"
quietly curl -fsSL -o "$WORK/src/$tarball" "$MIRROR/$tarball" || exit 1
quietly curl -fsSL -o "$WORK/src/$tarball.sig" "$MIRROR/$tarball.sig" || exit 1

if ! gpg --list-keys "$SIGNING_KEY" >/dev/null 2>&1; then
  quietly gpg --keyserver "$KEYSERVER" --recv-keys "$SIGNING_KEY" || exit 1
fi
# A good signature is not enough: it must be by the maintainer's key.
if ! gpg --status-fd 1 --verify "$WORK/src/$tarball.sig" "$WORK/src/$tarball" 2>>"$LOG" |
  tee -a "$LOG" | grep -E "^\[GNUPG:\] VALIDSIG .*\b$SIGNING_KEY\b" >/dev/null; then
  close_line
  err "bad or missing signature on $tarball (want key $SIGNING_KEY); not building it"
  detail "${DIM}full output: ${LOG/#$HOME/\~}$RESET" >&2
  exit 1
fi

# Build dependencies: only the headers that are missing, unpacked without root.
deps=()
[[ -f /usr/include/ncurses.h || -f /usr/include/curses.h ]] || deps+=(libncurses-dev)
[[ -f /usr/include/security/pam_appl.h ]] || deps+=(libpam0g-dev)
cppflags="" ldflags=""
if [[ ${#deps[@]} -gt 0 ]]; then
  mkdir -p "$WORK/debs" "$WORK/deps"
  (cd "$WORK/debs" && quietly apt-get download "${deps[@]}") || exit 1
  for deb in "$WORK"/debs/*.deb; do
    quietly dpkg -x "$deb" "$WORK/deps" || exit 1
  done
  cppflags="-I$WORK/deps/usr/include"
  ldflags="-L$WORK/deps/$ARCH_LIB"
fi

# Build and install.
quietly tar -xzf "$WORK/src/$tarball" -C "$WORK/src" || exit 1
cd "$WORK/src/screen-$latest"
quietly ./configure --prefix="$PREFIX" "${CONFIG[@]}" CPPFLAGS="$cppflags" LDFLAGS="$ldflags" || exit 1
quietly make -j"$(nproc)" || exit 1
quietly make install || exit 1

installed=$("$PREFIX/bin/screen" -v 2>/dev/null | sed -n 's/^Screen version \([0-9.]*\).*/\1/p') || installed=""
if [[ "$installed" != "$latest" ]]; then
  close_line
  err "built screen $latest, but $PREFIX/bin/screen reports '${installed:-nothing}'"
  exit 1
fi
mkdir -p "${STAMP%/*}"
echo "$build" >"$STAMP"
echo " $DIM($(elapsed "$started"))$RESET"
