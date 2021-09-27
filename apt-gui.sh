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
  gpick
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

  ipython3
)

install() {
  for i in $@; do
    if [ -z "$(apt-cache show $i 2>/dev/null)" ]; then
      echo " > Package $i not available on repo."
    else
      echo " > Add package $i to the install list"
      packages="$packages $i"
    fi
  done
  sudo apt update
  sudo apt install -y $packages
  sudo apt autoremove
}

install "${PACKAGES[@]}"
