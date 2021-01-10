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
  gitk
  git-gui

  # Other
  neovim
  gedit
  tilix
  ack
  screen
  ncdu
  htop
  gdebi
  ffmpeg
  vlc
  gparted
  tree
  feh
  youtube-dl
  colordiff
  jq
  npm
  wavemon
  nmap
  hardinfo
  mosh
  detox
  evince
  neofetch
  meld


  # System
  bluez-tools
  nfs-common
  snapd
  d-feet
  ntp

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
