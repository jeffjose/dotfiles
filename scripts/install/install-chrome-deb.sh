#!/usr/bin/env bash
#
# Install / reinstall Google Chrome from Google's .deb  — the B path.
#
#   A (AppImage) : does not exist. Google ships no AppImage, official or
#                  otherwise worth trusting, so Chrome is .deb-only. This is
#                  the difference from `code`, which has both paths.
#   B (.deb)     : automatic  → scripts/update/update_chrome.sh, run by `uq`
#                              (ETag-checked, so it no-ops when unchanged)
#                  manual     → this script
#
# Use this for a fresh machine or to put Chrome back after an accidental
# `dpkg -P`. Day-to-day updates need no action: `uq` handles them.
#
# Unlike update_chrome.sh this always downloads and installs, with no ETag
# short-circuit — a reinstall has to work even when the version is unchanged.
#
# Jeffrey Jose | 2026-08-01

set -euo pipefail

URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
DEB="$HOME/Downloads/chrome.deb"

echo "🔄 Installing Google Chrome from .deb (path B)..."

echo -n "Currently installed (.deb): "
dpkg-query -W -f='${Version}\n' google-chrome-stable 2>/dev/null || echo "not installed"

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

echo "📦 Installing (needs sudo)..."
sudo dpkg -i "$DEB" || {
  echo "⚠️  dpkg reported unmet dependencies — resolving..." >&2
  sudo apt-get -f install -y
}

echo -n "✅ Installed (.deb): "
dpkg-query -W -f='${Version}\n' google-chrome-stable

# update_chrome.sh caches the download ETag to skip unchanged builds. We just
# replaced the package outside that flow, so drop the cache — otherwise the next
# `uq` may believe it is current when it is not.
rm -f "$HOME/Downloads/chrome.etag"
echo "ℹ️  Cleared the update_chrome.sh ETag cache so \`uq\` re-checks next run."
