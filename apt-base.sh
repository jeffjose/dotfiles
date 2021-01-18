#!/bin/bash
#
# Jeffrey Jose | Jan 10, 2021
#

echo "-----------------"
echo "Ubuntu base packages"
echo "-----------------"

PACKAGES=(

  # Essentials
  curl
  wget
  sudo
  tcsh
  openssh-server
  traceroute
  build-essential

  # Git
  git

  # Other
  ack
  screen
  ncdu
  htop
  neovim
  tree
  nmap
  hardinfo
  neofetch
  moreutils
  sshpass
  golang

)

printf -v JOINED '%s ' "${PACKAGES[@]}"

#sudo apt update
#sudo apt install -y $JOINED
#sudo apt autoremove

## Install
sudo apt update
for package in "${PACKAGES[@]}"; do
  echo "---------------------"
  echo "  Installing $package"
  echo "---------------------"
  sudo apt install -y $package
done
sudo apt autoremove
