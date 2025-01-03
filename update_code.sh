#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
CODE_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
TEMP_PATH="/tmp/code.deb"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🔄 Updating VS Code..."

# Get current version
echo -n "Current version: "
code --version | head -n 1 || echo "not installed"

# Download new version
echo "📥 Downloading latest stable build..."
if ! wget -O "$TEMP_PATH" \
  --header="user-agent: $USER_AGENT" \
  "$CODE_URL"; then
  echo "Error: Failed to download VS Code"
  exit 1
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
