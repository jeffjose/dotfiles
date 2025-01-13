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

# Define GitHub repositories to install
declare -a GITHUB_REPOS=(
  "https://github.com/jeffjose/mediainfo" # CLI tool for media file information
)

# Define packages to install
# Each package has a brief description of its purpose
declare -a CRATES=(
  # File finding utilities
  "fd-find"    # Modern find replacement
  "find-files" # Another find alternative

  # Git utilities
  "timeago-cli" # For gitstatus (prompt)
  "onefetch"    # Git repository summary
  "git-absorb"  # Automatically absorb staged changes into your current branch

  # Cargo utilities
  "cargo-bump"     # For bumping versions
  "cargo-edit"     # For editing Cargo.toml files
  "cargo-update"   # Update installed binaries
  "cargo-make"     # Task runner (alternative to yarn/npm run)
  "cargo-cache"    # Cache statistics
  "cargo-binstall" # Binary installer

  # CLI utilities
  "rargs"     # Command-line argument parsing
  "names"     # Name generator
  "tzupdate"  # Timezone updater
  "ripgrep"   # Fast search tool (grep replacement)
  "xh"        # Modern HTTP client
  "gifski"    # GIF encoder
  "hyperfine" # Command-line benchmarking
  "lla"       # ls alternative with plugin support
  "rustic-rs" # Backup tool (Rust version of restic)
)

# Install GitHub repositories
echo "📦 Installing packages from GitHub..."
for repo in "${GITHUB_REPOS[@]}"; do
  echo "Installing from $repo..."
  $HOME/.cargo/bin/cargo install --quiet --git "$repo"
done

# Install packages (doesn't update existing ones)
echo "📦 Installing Cargo packages..."
for crate in "${CRATES[@]}"; do
  echo "Installing $crate..."
  $HOME/.cargo/bin/cargo install --quiet "$crate"
done

# Install tuc with regex features separately
echo "📦 Installing tuc with regex features..."
$HOME/.cargo/bin/cargo install --quiet tuc --features regex

# Update all installed packages
echo "⬆️  Updating all installed packages..."
$HOME/.cargo/bin/cargo install-update -a

# Final toolchain update
echo "🔄 Final toolchain update..."
rustup update stable

echo "✨ All done! Your Rust environment is up to date!"
