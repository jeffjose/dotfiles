#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "-----------------"
echo "Ubuntu server packages"
echo "-----------------"

PACKAGES=(

  # Essentials
  curl
  wget
  sudo
  tcsh
  openssh-server
  traceroute

  # Dev
  golang
  ruby-full
  clang-format
  build-essential
  python3-pip

  # Git
  git

  # Other
  neovim
  ack
  screen
  ncdu
  htop
  ffmpeg
  tree
  youtube-dl
  colordiff
  jq
  npm
  wavemon
  nmap
  hardinfo
  mosh
  detox
  neofetch

  # System
  bluez-tools
  nfs-common
  snapd
  d-feet
  ntp
  dconf-cli
  tshark

  # CLI Replacements
  aria2
  entr
  moreutils

  # Containers
  runc
  podman # You might need to run `sudo systemctl start podman`
  buildah
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
