#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#

sudo true

echo "Installing VS Code ..."

echo -n "Before: "
code --version | head -n 1

wget -O /tmp/code.deb \
  --header="user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" \
  "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"

sudo dpkg -Ei /tmp/code.deb

echo -n " After: "
code --version | head -n 1
