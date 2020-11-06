#!/bin/bash
#
# Jeffrey Jose
#

# Packages
sudo apt install -y git neovim curl moreutils tilix ack screen gitk ncdu htop tcsh gdebi ffmpeg vlc gedit gparted tree feh youtube-dl ntp colordiff bluez-tools d-feet jq npm openssh-server git-gui wavemon nfs-common nmap hardinfo mosh golang clang-format snapd

# Torrents
sudo apt install -y qbittorrent transmission

# CLI Replacements
sudo apt install -y aria2 entr

# Shutter
sudo add-apt-repository ppa:linuxuprising/shutter
sudo apt-get update
sudo apt install -y shutter

# Numix
sudo add-apt-repository ppa:numix/ppa
sudo apt-get update
sudo apt-get install -y numix-gtk-theme numix-icon-theme-circle

# ppa-manager
sudo add-apt-repository ppa:webupd8team/y-ppa-manager
sudo apt-get update
sudo apt install -y y-ppa-manager

mkdir -p ~/bin/
ln /usr/bin/screen ~/bin/scrn -s

# Install yarn
#curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
#echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
#sudo apt-get update && sudo apt-get -y install yarn
curl -o- -L https://yarnpkg.com/install.sh | bash

# Yarn packages
./yarn.sh

# VIM
./vim.sh

# Cargo / Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

./cargo.sh

# Fonts
./fonts.sh

# Install dart
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
sudo apt-get update && sudo apt-get -y dart

# Install gh (github CLI)
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
sudo apt-add-repository https://cli.github.com/packages
sudo apt update
sudo apt install -y gh

# Flutter
sudo snap install flutter --classic

# Patch ntp servers
sudo patch /etc/ntp.conf ntp.patch

# Remove packages
sudo apt autoremove

# pip install
./pip.sh

ssh-keygen -t rsa -b 4096 -C "jeffjosejeff@gmail.com"
ssh-add ~/.ssh/id_rsa


echo "Things manually to install"
echo " 1. Chrome"
echo " 2. VS Code"
echo " 3. Android Studio"
