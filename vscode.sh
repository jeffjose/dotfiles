#!/bin/bash
#
# Jeffrey Jose | Apr 20, 2020
#

# Get a list of installed extensions via
# `code --list-extensions`

echo "-----------------"
echo "VS code"
echo "-----------------"

# vim
code --force --install-extension vscodevim.vim

# formatter: prettier
code --force --install-extension esbenp.prettier-vscode

# .svelte
code --force --install-extension svelte.svelte-vscode

# .py
code --force --install-extension ms-python.python

# .service
code --force --install-extension coolbear.systemd-unit-file

# .csv
code --force --install-extension mechatroner.rainbow-csv

# tailwindcss: order class names
code --force --install-extension heybourn.headwind

# Themes
code --force --install-extension monokai.theme-monokai-pro-vscode
code --force --install-extension PKief.material-icon-theme

# Format all files
code --force --install-extension lacroixdavid1.vscode-format-context-menu

# Docker
code --force --install-extension ms-azuretools.vscode-docker

# Python
code --force --install-extension ms-python.python

# Firestore syntax highlight rules
code --force --install-extension toba.vsfire

# Firebase explorer
code --force --install-extension jsayol.firebase-explorer

# TailwindCSS: CSS classname completion
code --force --install-extension bradlc.vscode-tailwindcss

# Flutter
code --force --install-extension Dart-Code.flutter

# Dart
code --force --install-extension Dart-Code.dart-code

# Bracket Pair Colorizer
code --force --install-extension CoenraadS.bracket-pair-colorizer-2

# PostCSS
code --force --install-extension ricard.postcss

# Error Lens: Show errors inline
code --force --install-extension ms-vscode-remote.remote-ssh

# Git Lens
code --force --install-extension eamodio.gitlens

# Output tab colorizer
code --force --install-extension IBM.output-colorizer

# Kotlin
code --force --install-extension mathiasfrohlich.Kotlin
