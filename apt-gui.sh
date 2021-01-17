#!/bin/bash
#
# Jeffrey Jose | Jan 10, 2021
#

echo "-----------------"
echo "Ubuntu GUI packages"
echo "-----------------"

PACKAGES=(

  # Git
  gitk
  git-gui

  # Other
  gedit
  tilix
  gdebi
  evince
  meld
  vlc
  gparted
  feh

  # Torrents
  #qbittorrent
  transmission

  # Fonts
  fonts-firacode
  fonts-inter
  fonts-noto-color-emoji
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
