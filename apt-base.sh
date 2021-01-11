#!/bin/bash
#
# Jeffrey Jose | Jan 10, 2021
#

echo "-----------------"
echo "Ubuntu base packages"
echo "-----------------"

PACKAGES=(

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
