#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "-----------------"
echo "Ubuntu packages with PPA"
echo "-----------------"
# Shutter
sudo add-apt-repository ppa:linuxuprising/shutter

# Numix
sudo add-apt-repository ppa:numix/ppa

# ppa-manager
sudo add-apt-repository ppa:webupd8team/y-ppa-manager

# Dart
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'

# Install gh (github CLI)
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
sudo apt-add-repository https://cli.github.com/packages

sudo apt-get update

PACKAGES=(
  # Shutter
  shutter

  # Numix
  numix-gtk-theme
  numix-icon-theme-circle

  # PPA Manager
  y-ppa-manager

  # Dart
  dart

  # Github CLI
  gh
)

# Install
for package in "${PACKAGES[@]}"; do
  sudo apt-get install -y $package
done
