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

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🔄 Updating Cursor IDE..."

# Print current MD5
if [ -f "$CURSOR_PATH" ]; then
  echo -n "Current MD5: "
  md5sum "$CURSOR_PATH" | cut -d' ' -f1
fi

# Download new version
echo "📥 Downloading latest stable build..."
if ! wget -q -O "$TEMP_PATH" \
  --header="user-agent: $USER_AGENT" \
  "$DOWNLOAD_URL"; then
  echo "Error: Failed to download Cursor"
  exit 1
fi

# Install new version
echo "📦 Installing Cursor..."
mkdir -p "$(dirname "$CURSOR_PATH")"
sudo mv "$TEMP_PATH" "$CURSOR_PATH"
sudo chmod a+rwx "$CURSOR_PATH"

# Print new MD5
echo -n "Updated MD5: "
md5sum "$CURSOR_PATH" | cut -d' ' -f1

echo "✅ Cursor IDE update complete!"
