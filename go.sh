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

  # json diff
  github.com/josephburnett/jd@latest
)

for package in ${PACKAGES[@]}
do
  echo "Installing $package"
  go install -v $package
  echo ""
done
