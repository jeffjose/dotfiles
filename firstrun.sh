#!/bin/bash
#
# Jeffrey Jose
#

# Packages
sudo apt install -y git neovim curl moreutils tilix ack screen gitk ncdu htop qbittorrent tcsh gdebi ffmpeg vlc gedit gparted tree feh youtube-dl ntp colordiff bluez-tools d-feet jq npx npm

# Shutter
sudo add-apt-repository ppa:linuxuprising/shutter
sudo apt-get update
sudo apt install -y shutter

# Numix
sudo add-apt-repository ppa:numix/ppa
sudo apt-get update
sudo apt-get install -y numix-gtk-theme numix-icon-theme-circle numix-icon-theme-square


mkdir -p ~/bin/
ln /usr/bin/screen ~/bin/scrn -s

# Install yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update && sudo apt-get -y install yarn

# Yarn packages
yarn global add t-get yarn-recursive

# Patch ntp servers
sudo patch /etc/ntp.conf ntp.patch

# Remove packages
sudo apt autoremove

ssh-keygen -t rsa -b 4096 -C "jeffjosejeff@gmail.com"
ssh-add ~/.ssh/id_rsa
