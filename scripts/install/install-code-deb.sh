#!/usr/bin/env bash
#
# Install / reinstall VS Code from Microsoft's .deb  — the B path.
#
#   A (default, automatic) : AppImage, via scripts/update/update_code.sh
#                            → kept current by `uq` (appimage update --all)
#   B (this script, manual): Microsoft's .deb into /usr/bin/code
#                            → deliberately NOT in `uq`; run it by hand
#
# `code` used to be listed in misc/package.toml, so update_deb.sh reinstalled the
# .deb on every `uq` run even though the AppImage already owned the app. That
# entry is gone, which means nothing automatic installs the .deb any more — this
# script is where that capability now lives, so it stays findable.
#
# NOTE: ~/bin/code (the AppImage wrapper) shadows /usr/bin/code in PATH. After
# running this, a bare `code` still launches the AppImage; use the full path
# /usr/bin/code to get the .deb build.
#
# Not an updater: it always fetches and installs the current stable build.
# Re-run it whenever you want the .deb refreshed.
#
# Jeffrey Jose | 2026-08-01

set -euo pipefail

URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
DEB="$HOME/Downloads/code.deb"

echo "🔄 Installing VS Code from .deb (path B)..."

echo -n "Currently installed (.deb): "
dpkg-query -W -f='${Version}\n' code 2>/dev/null || echo "not installed"

mkdir -p "$(dirname "$DEB")"
echo "📥 Downloading current stable build..."
curl -fL --progress-bar -o "$DEB" "$URL"

# Sanity-check before handing it to dpkg — a captive portal or an error page
# would otherwise be passed straight through as a "package".
if ! dpkg-deb -I "$DEB" >/dev/null 2>&1; then
  echo "❌ Download is not a valid .deb: $DEB" >&2
  exit 1
fi
echo "📦 Package: $(dpkg-deb -f "$DEB" Package) $(dpkg-deb -f "$DEB" Version)"

# The postinst asks, via debconf, whether to add Microsoft's apt repo — and it
# defaults to yes. Answer it up front, for two reasons:
#
#   1. Unanswered, the prompt blocks dpkg indefinitely with the package left
#      half-configured. Easy to miss when the script is run from another window.
#   2. Yes is the wrong answer here. The repo would let `apt upgrade` update the
#      .deb on its own, quietly restoring the automatic path that was
#      deliberately removed from `uq`. This .deb is meant to stay pinned until
#      this script is run again.
echo "⚙️  Declining the Microsoft apt repo (keeps the .deb pinned, not auto-updated)..."
echo "code code/add-microsoft-repo boolean false" | sudo debconf-set-selections

echo "📦 Installing (needs sudo)..."
sudo env DEBIAN_FRONTEND=noninteractive dpkg -i "$DEB" || {
  echo "⚠️  dpkg reported unmet dependencies — resolving..." >&2
  sudo apt-get -f install -y
}

echo -n "✅ Installed (.deb): "
dpkg-query -W -f='${Version}\n' code

echo "ℹ️  A bare \`code\` still runs the AppImage (~/bin/code shadows /usr/bin/code)."
