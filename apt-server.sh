#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "-----------------"
echo "Ubuntu server packages"
echo "-----------------"

PACKAGES=(

  # Other
  ffmpeg
  youtube-dl
  colordiff
  jq
  wavemon
  mosh
  detox
  lxc

  # System
  bluez-tools
  nfs-common
  snapd
  d-feet
  ntp
  dconf-cli
  tshark

  # Containers
  runc
  podman # You might need to run `sudo systemctl start podman`
  podman-docker
  buildah
  skopeo
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
