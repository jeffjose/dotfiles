#!/bin/bash
#
# Jeffrey Jose | Nov 01, 2020
#

echo "-----------------"
echo "Python Packages"
echo "-----------------"

PACKAGES=(
  yapf speedtest-cli black youtube-dlc
)

pip install --upgrade ${PACKAGES[*]}
