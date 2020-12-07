#!/bin/bash
#
# Jeffrey Jose | Oct 21, 2020
#

echo "-----------------"
echo "Cargo / Rust"
echo "-----------------"

CRATES=(

  # For gitstatus (prompt)
  timeago-cli

  # For bumping versions
  cargo-bump


  # git summary
  onefetch

)

cargo install ${CRATES[*]}
