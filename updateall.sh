#!/bin/bash
#
# Jeffrey Jose | Jan 10, 2016
#
#setenv DEBIAN_FRONTEND noninteractive

# Update packages
echo -e ''
echo -e '---------------------------------------------------------'
echo -e 'Updating apt packages'
echo -e '---------------------------------------------------------'
echo -e ''
sudo apt -y autoclean
sudo apt -y clean
sudo apt -y update
sudo apt -y upgrade
sudo apt -y autoremove

# Update node packages
echo -e ''
echo -e '---------------------------------------------------------'
echo -e 'Updating node packages'
echo -e '---------------------------------------------------------'
echo -e ''
yarn global upgrade all

# Flutter
#flutter upgrade --force

# Go (doesnt work)
# go get -u all

# Update apps
echo -e ''
echo -e '---------------------------------------------------------'
echo -e 'Updating rust, vim, code & chrome'
echo -e '---------------------------------------------------------'
echo -e ''

$HOME/dotfiles/update_rust.sh
$HOME/dotfiles/update_vim.sh
$HOME/dotfiles/update_code.sh
$HOME/dotfiles/update_chrome.sh
