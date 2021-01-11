#!/bin/bash
#
# Jeffrey Jose | Jan 7, 2021
#

echo "----------------------------"
echo "Ubuntu base packages with PPA"
echo "----------------------------"

sudo apt-get update

PACKAGES=(
)

# Install
for package in "${PACKAGES[@]}"; do
  echo "---------------------"
  echo "  Installing $package"
  echo "---------------------"
  sudo apt-get install -y $package
done
