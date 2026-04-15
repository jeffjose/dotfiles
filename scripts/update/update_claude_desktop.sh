#!/bin/env bash
#
# Jeffrey Jose | Apr 15, 2026
#
set -e # Exit on error

# Constants
REPO="aaddrick/claude-desktop-debian"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
DEST="$HOME/bin/claude-desktop"
TAG_FILE="$HOME/bin/.claude-desktop.tag"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ASSET_SUFFIX="amd64.AppImage" ;;
  aarch64|arm64) ASSET_SUFFIX="arm64.AppImage" ;;
  *) echo "Error: Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Personal-machine guard: skip on Google corp hosts.
# Be defensive — check multiple sources, fail-closed (skip) on any uncertainty.
is_corp_host() {
  local fqdn shortname domain

  # Try several ways to get the FQDN
  fqdn=$(hostname -f 2>/dev/null || true)
  [ -z "$fqdn" ] && fqdn=$(hostname --fqdn 2>/dev/null || true)
  [ -z "$fqdn" ] && fqdn=$(hostname 2>/dev/null || true)
  shortname=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
  domain=$(hostname -d 2>/dev/null || true)

  # Lowercase for matching
  fqdn=$(echo "$fqdn" | tr '[:upper:]' '[:lower:]')
  domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
  shortname=$(echo "$shortname" | tr '[:upper:]' '[:lower:]')

  echo "  hostname -f : $fqdn" >&2
  echo "  hostname -d : $domain" >&2
  echo "  hostname -s : $shortname" >&2

  # Match on FQDN ending in google.com / corp.google.com
  case "$fqdn" in
    *.google.com|*.corp.google.com|*.c.googlers.com) return 0 ;;
  esac
  case "$domain" in
    google.com|corp.google.com|c.googlers.com) return 0 ;;
  esac

  # Belt and suspenders: glinux-only paths
  if [ -f /etc/lsb-release ] && grep -qi 'glinux\|goobuntu' /etc/lsb-release 2>/dev/null; then
    return 0
  fi
  if [ -d /google ] || [ -d /usr/local/google ]; then
    return 0
  fi

  return 1
}

# Interactive confirmation with smart default based on detection.
# Default is what we *think* is right; user can override.
confirm() {
  local prompt="$1" default="$2" reply
  local hint
  if [ "$default" = "y" ]; then
    hint="[Y/n]"
  else
    hint="[y/N]"
  fi
  # If not running interactively, fall back to the default
  if [ ! -t 0 ]; then
    echo "$prompt $hint (non-interactive, using default: $default)"
    [ "$default" = "y" ]
    return $?
  fi
  read -r -p "$prompt $hint " reply </dev/tty || reply=""
  reply=${reply:-$default}
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

echo "🔄 Checking for Claude Desktop updates..."

# Get current version
echo -n "Current version: "
if [ -f "$TAG_FILE" ]; then
  cat "$TAG_FILE"
else
  echo "not installed"
fi

echo "🔍 Checking for new version..."

# Fetch latest release metadata FIRST — no point prompting if there's nothing to do.
RELEASE_JSON=$(curl -sL "$API_URL")
TAG_NAME=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -n1 | cut -d'"' -f4)
DOWNLOAD_URL=$(echo "$RELEASE_JSON" \
  | grep '"browser_download_url"' \
  | grep "$ASSET_SUFFIX\"" \
  | grep -v zsync \
  | head -n1 \
  | cut -d'"' -f4)

if [ -z "$TAG_NAME" ] || [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: Could not find latest AppImage for $ARCH"
  exit 1
fi

echo "Latest release: $TAG_NAME"

# Compare against installed tag — early exit before any prompt.
CURRENT_TAG=""
if [ -f "$TAG_FILE" ]; then
  CURRENT_TAG=$(cat "$TAG_FILE")
fi

if [ "$CURRENT_TAG" = "$TAG_NAME" ] && [ -x "$DEST" ]; then
  echo "✅ Claude Desktop is already up to date! ($TAG_NAME)"
  exit 0
fi

# An update is available — now check host and prompt.
echo "🔍 Update available. Checking host identity..."
if is_corp_host; then
  echo "🏢 Detected a Google corp host — Claude Desktop should NOT be installed here."
  if ! confirm "Override and install anyway?" "n"; then
    echo "⏭  Skipping Claude Desktop install."
    exit 0
  fi
  echo "⚠️  Proceeding with install on corp host (user override)."
else
  echo "🏠 Detected a personal host — Claude Desktop is safe to install."
  if ! confirm "Proceed with install/update?" "y"; then
    echo "⏭  Skipping Claude Desktop install (user declined)."
    exit 0
  fi
fi

# Download
mkdir -p "$HOME/bin"
TMP=$(mktemp --suffix=.AppImage)
trap 'rm -f "$TMP"' EXIT

echo "📥 Downloading $DOWNLOAD_URL..."
if ! curl -L --fail -o "$TMP" "$DOWNLOAD_URL"; then
  echo "Error: Failed to download Claude Desktop"
  exit 1
fi

# Install
echo "📦 Installing Claude Desktop..."
if ! mv "$TMP" "$DEST"; then
  echo "Error: Failed to install Claude Desktop"
  exit 1
fi
chmod +x "$DEST"
echo "$TAG_NAME" >"$TAG_FILE"

# Verify installation
echo -n "Updated version: "
cat "$TAG_FILE"

echo "✅ Claude Desktop update complete!"
