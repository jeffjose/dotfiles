#!/usr/bin/env bash
#
# Jeffrey Jose | 13 June, 2021

# Copy over fonts
cp -v apple-system/*otf $HOME/.local/share/fonts

# Rebuild cache
fc-cache -f -v
