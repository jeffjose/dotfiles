#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "-----------------"
echo "Ubuntu packages"
echo "-----------------"

PACKAGES=(

  # Git
  git
  gitk
  git-gui

  # Other
  neovim
  curl
  tilix
  ack
  screen
  ncdu
  htop
  tcsh
  gdebi
  ffmpeg
  vlc
  gedit
  gparted
  tree
  feh
  youtube-dl
  ntp
  colordiff
  d-feet
  jq
  npm
  openssh-server
  wavemon
  nfs-common
  nmap
  hardinfo
  mosh
  golang
  clang-format
  snapd
  detox
  evince
  neofetch

  # System
  bluez-tools

  # Torrents
  #qbittorrent
  transmission

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

sudo apt-get update
sudo apt-get install -y $JOINED
sudo apt-get autoremove

## Install
#for package in "${PACKAGES[@]}"; do
#  sudo apt-get install -y $package
#done
