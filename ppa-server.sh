#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "-----------------"
echo "Ubuntu server packages with PPA"
echo "-----------------"

# Install gh (github CLI)
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
sudo apt-add-repository -y https://cli.github.com/packages

PACKAGES=(

  # Github CLI
  gh

  # Neovim
  neovim
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
