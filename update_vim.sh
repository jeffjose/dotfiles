#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#

sudo true

echo "Installing nvim ..."

echo -n "Before: "
/usr/bin/nvim --version | grep "NVIM v" --color=never

wget -qO /tmp/nvim "https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage"

sudo mv /tmp/nvim /usr/bin/nvim
sudo chmod a+rwx /usr/bin/nvim

echo -n " After: "
/usr/bin/nvim --version | grep "NVIM v" --color=never
