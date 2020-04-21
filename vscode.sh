#!/bin/bash
#
# Jeffrey Jose | Apr 20, 2020
#

echo "-----------------"
echo "VS code"
echo "-----------------"

# vim
code --install-extension vscodevim.vim

# formatter: prettier
code --install-extension esbenp.prettier-vscode

# .svelte
code --install-extension JamesBirtles.svelte-vscode

# .py
code --install-extension ms-python.python

# .service
code --install-extension coolbear.systemd-unit-file

# .csv
code --install-extension mechatroner.rainbow-csv

# tailwindcss: order class names
code --install-extension heybourn.headwind

# Themes
code --install-extension monokai.theme-monokai-pro-vscode
code --install-extension PKief.material-icon-theme

# Format all files
code --install-extension lacroixdavid1.vscode-format-context-menu

# Docker
code --install-extension ms-azuretools.vscode-docker
