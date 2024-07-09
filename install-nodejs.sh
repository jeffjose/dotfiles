#!/bin/bash
#
# Jeffrey Jose
#
# NodeJS

sudo rm -rf /etc/apt/sources.list.d/nodesource.list

sudo apt --fix-broken install
sudo apt autoremove
sudo apt update
sudo apt remove -y nodejs
sudo apt remove -y nodejs-doc

# Using Ubuntu
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -

sudo apt install -y g++ build-essential libnode72

sudo apt-get install -y nodejs
