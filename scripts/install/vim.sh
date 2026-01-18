#!/bin/bash
#
# Jeffrey Jose | May 2, 2020
#

echo "-----------------"
echo "VIM"
echo "-----------------"

# Install vim-plug
#
#
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim


# Install plugins
nvim -es -u ~/.config/nvim/init.vim +PlugInstall +qa

# Rust analyzer
mkdir -p ~/.local/bin
curl -L https://github.com/rust-analyzer/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-unknown-linux-gnu.gz | gunzip -c - > ~/.local/bin/rust-analyzer
chmod +x ~/.local/bin/rust-analyzer
