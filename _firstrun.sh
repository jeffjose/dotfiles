#!/bin/bash
#
# Jeffrey Jose
#

# Ubuntu packages
./apt-base.sh

# Ubuntu packages with ppa
./ppa-base.sh

if [ "$JEFFJOSE_MODE" == "SERVER" ]; then
  # Ubuntu packages
  ./apt-server.sh

  # Ubuntu packages with ppa
  ./ppa-server.sh

  elseif ["$JEFFJOSE_MODE" == "GUI" ]

  ./apt-gui.sh

  # Ubuntu packages with ppa
  ./ppa-gui.sh

fi

# linuxbrew
yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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

if [ "$JEFFJOSE_MODE" == "GUI" ]; then
  # Flutter
  sudo snap install flutter --classic

  # Android
  sudo usermod -aG plugdev jeffjose
  sudo apt-get install android-sdk-platform-tools-common
fi

# Patch ntp servers
sudo patch -f /etc/ntp.conf ntp.patch

# pip install
./pip.sh

# Remove packages
sudo apt autoremove

# SSH
yes | ssh-keygen -t rsa -b 4096 -C "jeffjosejeff@gmail.com" -f $HOME/.ssh/id_rsa -q -N ""
ssh-add $HOME/.ssh/id_rsa

# Setup SHELL
sudo chsh -s /bin/tcsh jeffjose

# Setup things
./setup.sh

echo "Things manually to do"
echo " 1. Install Chrome"
echo " 2. Install VS Code (https://code.visualstudio.com/docs/?dv=linux64_deb)"
echo " 3. Install Android Studio"
echo "   a. JAVA correct alternative (sudo update-alternatives --config java). Select - /usr/lib/jvm/java-13-openjdk-amd64/bin/java"
echo "   b. Accept all licenses 'yes | sdkmanager --licenses'"
