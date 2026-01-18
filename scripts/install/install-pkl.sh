#!/usr/bin/env bash

curl --output $HOME/bin/pkl https://github.com/apple/pkl/releases/latest/download/pkl-linux-amd64 -L

chmod a+rwx $HOME/bin/pkl
