#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#

echo "Installing Cargo & Rust ..."

rustup update stable
cargo install cargo-update && cargo install-update -a
