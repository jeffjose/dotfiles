#!/bin/bash
#
# Jeffrey Jose | Apr 20, 2020
#

# Get a list of installed extensions via
# `code --list-extensions`

echo "-----------------"
echo "VS code"
echo "-----------------"

EXTENSIONS=(

  # vim
  vscodevim.vim

  # formatter: prettier
  esbenp.prettier-vscode

  # .svelte
  svelte.svelte-vscode

  # .py
  ms-python.python

  # .service
  coolbear.systemd-unit-file

  # .csv
  mechatroner.rainbow-csv

  # tailwindcss: order class names
  heybourn.headwind

  # Themes
  monokai.theme-monokai-pro-vscode
  PKief.material-icon-theme

  # Format all files
  lacroixdavid1.vscode-format-context-menu

  # Docker
  ms-azuretools.vscode-docker

  # Firestore syntax highlight rules
  toba.vsfire

  # Firebase explorer
  jsayol.firebase-explorer

  # TailwindCSS: CSS classname completion
  bradlc.vscode-tailwindcss

  # Flutter
  Dart-Code.flutter

  # Dart
  Dart-Code.dart-code

  # Bracket Pair Colorizer
  CoenraadS.bracket-pair-colorizer-2

  # PostCSS
  ricard.postcss

  # Error Lens: Show errors inline
  ms-vscode-remote.remote-ssh

  # Git Lens
  eamodio.gitlens

  # Output tab colorizer
  IBM.output-colorizer

  # Kotlin
  mathiasfrohlich.Kotlin

  # XML
  redhat.vscode-xml

  # Dupe file in context menu
  gieson.dupe-file

  # ESLint
  dbaeumer.vscode-eslint

  # Kotlin
  fwcd.kotlin

  # Gitgraph
  mhutchie.git-graph

  # More Python
  ms-python.vscode-pylance

  # Remote ssh
  ms-vscode-remote.remote-ssh-edit

  # Gradle
  naco-siren.gradle-language

  # Colors for your code windows
  stuart.unique-window-colors

  # Improved error
  usernamehw.errorlens

  # TOML support
  bungcip.better-toml

  # I3 config
  dcasella.i3

  # Remove final new lines
  DoCode.vscode-remove-final-newlines

  # JSONNET
  heptio.jsonnet

  # Rust
  matklad.rust-analyzer
  rust-lang.rust
  statiolake.vscode-rustfmt
  vadimcn.vscode-lldb

  # Remote containers
  ms-vscode-remote.remote-containers

  # Proto3
  zxh404.vscode-proto3
)

# Install
for extension in "${EXTENSIONS[@]}"; do
  code --force --install-extension $extension
done
