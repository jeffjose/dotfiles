#!/bin/bash
#
# Jeffrey Jose
#

# Ubuntu packages
./apt.sh

# Ubuntu packages with ppa
./apt-ppa.sh

# linuxbrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

mkdir -p ~/bin/
ln /usr/bin/screen ~/bin/scrn -s

# Install Ruby
sudo apt install -y ruby-full

# Install yarn
curl -o- -L https://yarnpkg.com/install.sh | bash

# Yarn packages
./yarn.sh

# VIM
./vim.sh

# Cargo / Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

./cargo.sh

# Go packages
./go.sh

# Fonts
./fonts.sh

# Podman
./podman.sh

# Flutter
sudo snap install flutter --classic

# Patch ntp servers
sudo patch /etc/ntp.conf ntp.patch

# Remove packages
sudo apt autoremove

# pip install
./pip.sh

# Android
sudo usermod -aG plugdev jeffjose
sudo apt-get install android-sdk-platform-tools-common

ssh-keygen -t rsa -b 4096 -C "jeffjosejeff@gmail.com"
ssh-add ~/.ssh/id_rsa

echo "Things manually to install"
echo " 1. Chrome"
echo " 2. VS Code"
echo " 3. Android Studio"
echo "   a. JAVA correct alternative (sudo update-alternatives --config java). Select - /usr/lib/jvm/java-13-openjdk-amd64/bin/java"
echo "   b. Accept all licenses 'yes | sdkmanager --licenses'"
