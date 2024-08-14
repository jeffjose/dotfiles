#!/bin/bash
#
# Jeffrey Jose | Jan 06, 2020
#

echo "-----------------"
echo "Yarn"
echo "-----------------"

# Update node to latest
$HOME/.yarn/bin/yarn global add n
sudo $HOME/.yarn/bin/n latest

PACKAGES=(

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

  # compression size from stdin
  brotli-size-cli
  gzip-size-cli

  # Manage nodejs version
  n

  vercel

  n

  pnpm

)

# Run
$HOME/.yarn/bin/yarn global add ${PACKAGES[*]}
