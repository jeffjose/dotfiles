#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
CHROME_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
TEMP_PATH="$HOME/Downloads/chrome.deb"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
ETAG_FILE="$HOME/Downloads/chrome.etag"

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🔄 Checking for Google Chrome updates..."

# Get current version
echo -n "Current version: "
google-chrome --version || echo "not installed"

# Check ETag
echo "🔍 Checking for new version..."
CURRENT_ETAG=""
if [ -f "$ETAG_FILE" ]; then
  CURRENT_ETAG=$(cat "$ETAG_FILE")
fi

NEW_ETAG=$(curl -sI -A "$USER_AGENT" -L "$CHROME_URL" | grep -i "etag" | awk '{print $2}' | tr -d '"\r\n')

if [ -z "$NEW_ETAG" ]; then
  echo "⚠️  Could not determine version from server headers"
  echo "📥 Proceeding with download..."
else
  if [ "$CURRENT_ETAG" = "$NEW_ETAG" ]; then
    echo "✅ Chrome is already up to date! (ETag: $NEW_ETAG)"
    exit 0
  fi
fi

# Download new version
echo "📥 Downloading latest stable build..."
if ! wget -O "$TEMP_PATH" \
  --header="user-agent: $USER_AGENT" \
  "$CHROME_URL"; then
  echo "Error: Failed to download Chrome"
  exit 1
fi

# Save new ETag
echo "$NEW_ETAG" >"$ETAG_FILE"

# Install new version
echo "📦 Installing Chrome..."
if ! sudo dpkg -Ei "$TEMP_PATH"; then
  echo "Error: Failed to install Chrome"
  exit 1
fi

# Verify installation
echo -n "Updated version: "
google-chrome --version

echo "✅ Chrome update complete!"
