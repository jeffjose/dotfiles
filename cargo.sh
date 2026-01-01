#!/bin/bash
#
# cargo.sh - Rust/Cargo bootstrap for mise
# Author: Jeffrey Jose
# Created: Oct 21, 2020
#

echo "🦀 -----------------"
echo "🦀 Cargo / Rust"
echo "🦀 -----------------"

# Check if Rust is installed
if ! command -v rustc &>/dev/null; then
  echo "🔧 Rust not found. Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
else
  echo "✓ Rust is already installed"
fi

# Update Rust toolchain
echo "🔄 Updating Rust toolchain..."
rustup update stable

# Install/update mise (the tool that manages everything else)
echo "📦 Installing/updating mise..."
$HOME/.cargo/bin/cargo install mise

echo ""
echo "✨ Rust bootstrap complete!"
echo "   Cargo packages are now managed by mise."
echo "   See ~/.config/mise/config.toml"
