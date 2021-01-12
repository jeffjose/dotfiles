#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "----------------------------"
echo "Ubuntu GUI packages with PPA"
echo "----------------------------"

# Shutter
sudo add-apt-repository -y ppa:linuxuprising/shutter

# Numix
sudo add-apt-repository -y ppa:numix/ppa

# ppa-manager
sudo add-apt-repository -y ppa:webupd8team/y-ppa-manager

sudo apt update

PACKAGES=(
  # Shutter
  shutter

  # Numix
  numix-gtk-theme
  numix-icon-theme-circle

  # PPA Manager
  y-ppa-manager
)

# Install
for package in "${PACKAGES[@]}"; do
  echo "---------------------"
  echo "  Installing $package"
  echo "---------------------"
  sudo apt install -y $package
done
