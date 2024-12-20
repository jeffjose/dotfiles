#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#

sudo true

echo "Installing Google Chrome ..."

echo -n "Before: "
google-chrome --version

wget -O /tmp/chrome.deb \
  --header="user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" \
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

sudo dpkg -Ei /tmp/chrome.deb

echo -n " After: "
google-chrome --version
