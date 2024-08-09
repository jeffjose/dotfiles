#!/usr/bin/env bash

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
  echo "Wayland mode.."
  gsettings set org.gnome.desktop.input-sources xkb-options "['caps:ctrl_modifier']"
else
  echo "Non wayland mode .."
  setxkbmap -option
  xmodmap ~/.xmodmap
fi
