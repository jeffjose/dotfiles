#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
DOWNLOAD_URL="https://downloader.cursor.sh/linux/appImage/x64"
CURSOR_PATH="$HOME/bin/cursor"
TEMP_PATH="/tmp/cursor"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
ETAG_FILE="/tmp/cursor.etag"

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🔄 Checking for Cursor updates..."

# Get current version
echo -n "Current version: "
if [ -f "$CURSOR_PATH" ]; then
  md5sum "$CURSOR_PATH" | cut -d' ' -f1
else
  echo "not installed"
fi

# Check version metadata
echo "🔍 Checking for new version..."
CURRENT_ETAG=""
if [ -f "$ETAG_FILE" ]; then
  CURRENT_ETAG=$(cat "$ETAG_FILE")
fi

# Get headers from server using GET request with range
HEADERS_RESPONSE=$(curl -s -A "$USER_AGENT" -H "Range: bytes=0-0" "$DOWNLOAD_URL" -D - -o /dev/null)
NEW_ETAG=$(echo "$HEADERS_RESPONSE" | grep -i "etag" | awk '{print $2}' | tr -d '"\r\n')

if [ -z "$NEW_ETAG" ]; then
  echo "⚠️  Could not determine version from server headers"
  echo "📥 Proceeding with download..."
else
  if [ "$CURRENT_ETAG" = "$NEW_ETAG" ]; then
    echo "✅ Cursor is already up to date! (ETag: $NEW_ETAG)"
    exit 0
  fi
fi

# Download new version
echo "📥 Downloading latest stable build..."
if ! wget -v -O "$TEMP_PATH" \
  --header="user-agent: $USER_AGENT" \
  "$DOWNLOAD_URL"; then
  echo "Error: Failed to download Cursor"
  exit 1
fi

# Save new metadata
if [ -n "$NEW_ETAG" ]; then
  echo "$NEW_ETAG" >"$ETAG_FILE"
fi

# Install new version
echo "📦 Installing Cursor..."
mkdir -p "$(dirname "$CURSOR_PATH")"
sudo mv "$TEMP_PATH" "$CURSOR_PATH"
sudo chmod a+rwx "$CURSOR_PATH"

# Verify installation
echo -n "Updated version: "
md5sum "$CURSOR_PATH" | cut -d' ' -f1

echo "✅ Cursor update complete!"
