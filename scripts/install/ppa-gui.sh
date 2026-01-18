#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "----------------------------"
echo "Ubuntu GUI packages with PPA"
echo "----------------------------"

# ppa-manager
sudo add-apt-repository -y ppa:webupd8team/y-ppa-manager

PACKAGES=(

  # Numix
  numix-gtk-theme
  numix-icon-theme-circle

  # PPA Manager
  y-ppa-manager
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
