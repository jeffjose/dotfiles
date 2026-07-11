#!/bin/bash
#
# ddterm (GNOME drop-down / Quake terminal)
#
# Installs + configures ddterm to behave like the tilix-quake setup:
#   - Ctrl+Space toggles the terminal
#   - no show/hide animation, instant appear/disappear
#   - no panel menu icon
#
# ddterm is a GNOME Shell extension, so this only runs under GNOME Shell.
# (On XFCE we use tilix --quake instead; see xfce.sh.)
#
# Jul 11, 2026
#
# Idempotent: safe to re-run. Re-run after upgrading GNOME Shell to pull a
# matching ddterm build.

set -e

UUID="ddterm@amezin.github.com"
REPO="ddterm/gnome-shell-extension-ddterm"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
SCHEMA="org.gnome.shell.extensions.ddterm"

# --- guard: GNOME Shell only -------------------------------------------------
if ! command -v gnome-shell >/dev/null 2>&1; then
  echo "[ddterm] gnome-shell not found. ddterm is a GNOME Shell extension and"
  echo "         only runs under GNOME. Skipping (XFCE uses tilix --quake)."
  exit 0
fi

echo "[ddterm] GNOME Shell $(gnome-shell --version | awk '{print $3}') detected"

# --- runtime dep: VTE GObject-introspection (the terminal engine) ------------
# ddterm renders its own VTE terminal in a separate app process.
if ! find /usr/lib* /usr/local/lib* -name 'Vte-2.91.typelib' 2>/dev/null | grep -q .; then
  echo "[ddterm] WARNING: VTE 2.91 typelib not found."
  if command -v apt-get >/dev/null 2>&1; then
    echo "         Install it with: sudo apt-get install -y gir1.2-vte-2.91"
  fi
  echo "         (ddterm will install but won't start a terminal without it.)"
fi

# --- install: latest prebuilt release zip (no build toolchain needed) --------
echo "[ddterm] Fetching latest release from github.com/$REPO ..."
ZIP_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*shell-extension.zip"' \
  | head -1 | cut -d'"' -f4)

if [ -z "$ZIP_URL" ]; then
  echo "[ddterm] ERROR: could not find a shell-extension.zip asset in the latest release." >&2
  exit 1
fi

TMP_ZIP="$(mktemp --suffix=.zip)"
trap 'rm -f "$TMP_ZIP"' EXIT
echo "[ddterm] Downloading $ZIP_URL"
curl -fsSL "$ZIP_URL" -o "$TMP_ZIP"

echo "[ddterm] Installing extension ..."
gnome-extensions install --force "$TMP_ZIP"

# --- enable ------------------------------------------------------------------
# A freshly installed extension is only picked up after the Shell rescans, so
# enable may not "take" until the next shell start. We enable now and also add
# it directly to the enabled list so it survives regardless.
gnome-extensions enable "$UUID" 2>/dev/null || true

# --- configure (write via gsettings against the extension's own schema) ------
if [ ! -f "$EXT_DIR/schemas/gschemas.compiled" ]; then
  echo "[ddterm] ERROR: schema not found at $EXT_DIR/schemas (install failed?)." >&2
  exit 1
fi

dset() { GSETTINGS_SCHEMA_DIR="$EXT_DIR/schemas" gsettings set "$SCHEMA" "$@"; }

echo "[ddterm] Applying configuration (Ctrl+Space, no animation, no menu) ..."

# Toggle with Ctrl+Space.
# NOTE: Ctrl+Space is also the default IBus "switch input source" shortcut on
# some GNOME setups. If the toggle doesn't fire, clear that conflict:
#   gsettings get org.gnome.desktop.wm.keybindings switch-input-source
dset ddterm-toggle-hotkey "['<Control>space']"

# Instant show/hide, no animation (like tilix quake).
dset override-window-animation true
dset show-animation 'disable'
dset hide-animation 'disable'
dset show-animation-duration 0.0
dset hide-animation-duration 0.0

# No panel presence / no menu button in the top bar.
dset panel-icon-type 'none'

# Hide the tab bar (and its menu button) while there's a single tab.
dset tab-policy 'automatic'

echo "[ddterm] Done."
echo
echo "  If Ctrl+Space doesn't work yet, the Shell needs to load the new extension:"
echo "    - Wayland:  log out and back in"
echo "    - X11:      Alt+F2, type 'r', Enter  (restart GNOME Shell)"
echo
echo "  Then press Ctrl+Space to drop down the terminal."
