#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
CHROME_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
TEMP_PATH="/tmp/chrome.deb"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🔄 Updating Google Chrome..."

# Get current version
echo -n "Current version: "
google-chrome --version || echo "not installed"

# Download new version
echo "📥 Downloading latest stable build..."
if ! wget -O "$TEMP_PATH" \
  --header="user-agent: $USER_AGENT" \
  "$CHROME_URL"; then
  echo "Error: Failed to download Chrome"
  exit 1
fi

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
