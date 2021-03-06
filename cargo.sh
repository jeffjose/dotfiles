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

  # update installed binaries
  cargo-update

  # rargs (https://github.com/lotabout/rargs)
  rargs

  # find replacement
  find-files

)

# Install. This command doesnt update installed packages
$HOME/.cargo/bin/cargo install ${CRATES[*]}

# Update installed packages
$HOME/.cargo/bin/cargo install-update -a
