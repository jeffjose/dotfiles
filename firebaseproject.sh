#!/bin/bash
#
# Jeffrey Jose | 17 Nov, 2020

gron $HOME/.config/configstore/firebase-tools.json | grep --color=never $(pwd) | sed -n 's/.*"\(\S*\)".*/\1/p'
