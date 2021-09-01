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
  mtr-tiny
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
  liblinux-lvm-perl
  python-is-python3

  # To make `cargo install cargo-update` work
  libssl-dev
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
