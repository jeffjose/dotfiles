#!/bin/bash

sudo apt install podman
sudo touch /etc/sub{u,g}id
start_uid=$(cut -sd ":" -f "2,3" < /etc/subuid | tr ":" "+" | bc | sort -n | tail -n 1)
start_gid=$(cut -sd ":" -f "2,3" < /etc/subgid | tr ":" "+" | bc | sort -n | tail -n 1)
sudo usermod --add-subuids ${start_uid:=100000}-$(( ${start_uid:=100000} + "65535" )) $(whoami)
sudo usermod --add-subgids ${start_gid:=100000}-$(( ${start_gid:=100000} + "65535" )) $(whoami)
podman system migrate

# `sudo apt install runc` for runc
mkdir -p ~/.config/containers
echo 'runtime = "/usr/bin/crun"' >>  ~/.config/containers/libpod.conf
