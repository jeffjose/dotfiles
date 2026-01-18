#!/bin/bash
#
# XFCE
#
# Jan 10, 2021

if [ "$XDG_CURRENT_DESKTOP" == "XFCE" ]; then
  echo "[XFCE] Setting up tilix quake shortcut"

  # query using -
  #
  #   xfconf-query -c xfce4-keyboard-shortcuts -lv | grep tilix
  #
  xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Primary>space' -s 'tilix --quake' -n
fi
