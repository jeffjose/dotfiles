#!/bin/bash
#
# cargo.sh - Rust/Cargo package installer and updater
# Author: Jeffrey Jose
# Created: Oct 21, 2020
#

echo "🦀 -----------------"
echo "🦀 Cargo / Rust"
echo "🦀 -----------------"

# Update Rust toolchain first
echo "🔄 Updating Rust toolchain..."
rustup update stable

# Install these two packages separately since it needs special handling
echo "📦 Installing mise, timeago..."
$HOME/.cargo/bin/cargo install mise timeago-cli

# Update all installed packages
echo "⬆️  Updating all installed packages..."
$HOME/.cargo/bin/cargo install-update -a

# Final toolchain update
echo "🔄 Final toolchain update..."
rustup update stable

echo "✨ All done! Your Rust environment is up to date!"
