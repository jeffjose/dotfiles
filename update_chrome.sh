#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#

sudo true

echo "Installing Google Chrome ..."

echo -n "Before: "
google-chrome --version

wget -qO /tmp/chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

sudo dpkg -Ei /tmp/chrome.deb

echo -n " After: "
google-chrome --version
