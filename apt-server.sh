#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "-----------------"
echo "Ubuntu packages"
echo "-----------------"

PACKAGES=(

  # Essentials
  curl
  wget
  sudo
  tcsh
  openssh-server

  # Dev
  golang
  ruby-full
  clang-format
  build-essential
  python3-pip

  # Git
  git

  # Other
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

#sudo apt-get update
#sudo apt-get install -y $JOINED
#sudo apt-get autoremove

## Install
sudo apt-get update
for package in "${PACKAGES[@]}"; do
  echo "---------------------"
  echo "  Installing $package"
  echo "---------------------"
  sudo apt-get install -y $package
done
sudo apt-get autoremove
