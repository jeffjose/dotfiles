#!/bin/bash
#
# go.sh - Go package installer and updater
# Author: Jeffrey Jose
# Created: Nov 10, 2020
#

echo "🐹 -----------------"
echo "🐹 Go"
echo "🐹 -----------------"

# Define packages to install
# Each package has a brief description of its purpose
declare -a PACKAGES=(
  # JSON utilities
  "github.com/tomnomnom/gron@latest"   # Make JSON greppable
  "github.com/josephburnett/jd@latest" # JSON diff tool

  # CLI utilities
  "github.com/antonmedv/watch@latest" # Modern watch replacement
  "github.com/ericchiang/pup@latest"  # HTML parser for the command line
)

# Install packages
for package in ${PACKAGES[@]}; do
  echo "📦 Installing ${package}..."
  go install -v $package
done

echo "✨ All done! Go packages have been installed!"
