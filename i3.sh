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

# Run
sudo apt install ${PACKAGES[*]}
