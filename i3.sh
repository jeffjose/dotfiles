#!/bin/bash
#
# Jeffrey Jose | Jan 06, 2020
#

echo "-----------------"
echo "i3"
echo "-----------------"

PACKAGES=(
  i3
  i3status
  i3lock
  suckless-tools
  xsettingsd
  rofi
  lxappearance
)

install() {
  for i in $@; do
    if [ -z "$(apt-cache show $i 2>/dev/null)" ]; then
      echo " > package $i not available on repo."
    else
      echo " > add package $i to the install list"
      packages="$packages $i"
    fi
  done
  sudo apt update
  sudo apt install -y $packages
  sudo apt autoremove
}

install "${packages[@]}"
