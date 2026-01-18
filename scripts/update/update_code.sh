#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
CODE_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
TEMP_PATH="$HOME/Downloads/code.deb"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
ETAG_FILE="$HOME/Downloads/code.etag"

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🔄 Checking for VS Code updates..."

# Get current version
echo -n "Current version: "
code --version | head -n 1 || echo "not installed"

# Check version metadata
echo "🔍 Checking for new version..."
CURRENT_ETAG=""
if [ -f "$ETAG_FILE" ]; then
  CURRENT_ETAG=$(cat "$ETAG_FILE")
fi

HEADERS=$(curl -sI -A "$USER_AGENT" -L "$CODE_URL")
NEW_ETAG=$(echo "$HEADERS" | grep -i "etag" | awk '{print $2}' | tr -d '"\r\n')

if [ -z "$NEW_ETAG" ]; then
  echo "⚠️  Could not determine version from server headers"
  echo "📥 Proceeding with download..."
else
  if [ "$CURRENT_ETAG" = "$NEW_ETAG" ]; then
    echo "✅ VS Code is already up to date! (ETag: $NEW_ETAG)"
    exit 0
  fi
fi

# Download new version
echo "📥 Downloading latest stable build..."
if ! wget -O "$TEMP_PATH" \
  --header="user-agent: $USER_AGENT" \
  "$CODE_URL"; then
  echo "Error: Failed to download VS Code"
  exit 1
fi

# Save new metadata
if [ -n "$NEW_ETAG" ]; then
  echo "$NEW_ETAG" >"$ETAG_FILE"
fi

# Install new version
echo "📦 Installing VS Code..."
if ! sudo dpkg -Ei "$TEMP_PATH"; then
  echo "Error: Failed to install VS Code"
  exit 1
fi

# Verify installation
echo -n "Updated version: "
code --version | head -n 1

echo "✅ VS Code update complete!"
