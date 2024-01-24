#!/bin/bash
#
# Jeffrey Jose | Nov 10, 2020

echo "-----------------"
echo "Go"
echo "-----------------"

PACKAGES=(

  # Work with JSON
  github.com/tomnomnom/gron@latest

  # watch replacement
  github.com/antonmedv/watch@latest

  github.com/ericchiang/pup@latest
)

echo "Installing ${PACKAGES[@]}"

go install -v ${PACKAGES[*]}
