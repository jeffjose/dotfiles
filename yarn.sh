#!/bin/bash
#
# Jeffrey Jose | Jan 06, 2020
#

echo "-----------------"
echo "Yarn"
echo "-----------------"

PACKAGES=(
  t-get yarn-recursive npx coffeescript less firebase firebase-tools peerflix gulp-cli

  #  To create vscode theme from .tmtheme
  yo generator-code
  prettier @prettier/plugin-php @prettier/plugin-pug prettier-plugin-svelte

  # Typescript
  typescript ts-node

  # CLI Replacements
  tldr

  # PostCSS
  postcss-cli

)

# Run
$HOME/.yarn/bin/yarn global add ${PACKAGES[*]}
