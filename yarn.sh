#!/bin/bash
#
# Jeffrey Jose | Jan 06, 2020
#

echo "-----------------"
echo "Yarn"
echo "-----------------"

PACKAGES=(

  # npm
  npm@latest

  t-get yarn-recursive npx coffeescript less firebase firebase-tools peerflix gulp-cli

  # Typescript
  typescript ts-node

  # CLI Replacements
  tldr

  # PostCSS
  postcss-cli

  # astro
  astro

  # scss
  sass

  # degit
  degit


  #jest
  jest

)

# Run
$HOME/.yarn/bin/yarn global add ${PACKAGES[*]}
