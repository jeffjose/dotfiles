#!/bin/bash
#
# Jeffrey Jose | Nov 10, 2020

echo "-----------------"
echo "Go"
echo "-----------------"

PACKAGES=(

  # Work with JSON
  github.com/tomnomnom/gron

  # watch replacement
  github.com/antonmedv/watch
)

echo "Installing ${PACKAGES[@]}"

go get -v -u ${PACKAGES[*]}
