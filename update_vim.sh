#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
NVIM_URL="https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage"
NVIM_PATH="/usr/bin/nvim"
TEMP_PATH="/tmp/nvim"

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🔄 Updating Neovim..."

# Get current version
echo -n "Current version: "
$NVIM_PATH --version | grep "NVIM v" --color=never || echo "not installed"

# Download new version
echo "📥 Downloading latest nightly build..."
if ! wget -q "$NVIM_URL" -O "$TEMP_PATH"; then
  echo "Error: Failed to download Neovim"
  exit 1
fi

# Install new version
echo "📦 Installing Neovim..."
sudo mv "$TEMP_PATH" "$NVIM_PATH"
sudo chmod a+rwx "$NVIM_PATH"

# Verify installation
echo -n "Updated version: "
$NVIM_PATH --version | grep "NVIM v" --color=never

echo "✅ Neovim update complete!"
