#!/bin/bash
#
# Jeffrey Jose | Oct 21, 2020
#

echo "-----------------"
echo "Cargo / Rust"
echo "-----------------"

rustup update stable

CRATES=(

  # find replacement
  fd-find

  # For gitstatus (prompt)
  timeago-cli

  # For bumping versions
  cargo-bump

  # For editing Cargo.toml files
  cargo-edit

  # For doing background .rs file source check
  # #
  # Commenting out to save resources
  #bacon

  # git summary
  onefetch

  # update installed binaries
  cargo-update

  # rargs (https://github.com/lotabout/rargs)
  rargs

  # find replacement
  find-files


  # timezone update
  tzupdate

  # Binary install
  cargo-binstall

  # name generator
  names

  # Cargo make (alt to yarn run / npm run)
  cargo-make

  # cache stats
  cargo-cache

  # ripgrep (replacement for ack)
  ripgrep

  # xh is alternative to httpie / curl
  xh

  # gifski for gif
  gifski

  # rustic (rust version of restic backup)
  rustic-rs

  # hyperfine (benchmarking)
  hyperfine

  # git-absorb
  git-absorb


  # lla - alternative to ls with plugin support
  lla
)

# Install. This command doesnt update installed packages
$HOME/.cargo/bin/cargo install ${CRATES[*]}

$HOME/.cargo/bin/cargo install  tuc --features regex

# Update installed packages
$HOME/.cargo/bin/cargo install-update -a

# update toolchain to latest
rustup update stable
