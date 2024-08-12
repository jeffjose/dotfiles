#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#

sudo true

echo "Installing VS Code ..."

echo -n "Before: "
code --version | head -n 1

wget -qO /tmp/code.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"

sudo dpkg -Ei /tmp/code.deb

echo -n " After: "
code --version | head -n 1
