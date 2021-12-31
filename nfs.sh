#!/bin/bash
#
# Jeffrey Jose
#
# nfs

# $ sudo mount -av

sudo mkdir -p /mnt/monolith/Plex
sudo mkdir -p /mnt/monolith/deluge
sudo mkdir -p /mnt/monolith/jdownloader

sudo patch -b -u /etc/fstab -i fstab.patch

