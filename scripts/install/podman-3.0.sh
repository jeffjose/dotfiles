#!/usr/bin/bash

# From https://blog.jillejr.tech/podman-v3-docker-compose-on-ubuntu-xubuntu-20-10

# podman 3.0

. /etc/os-release

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -

sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install podman


# fuse-overlayfs

sudo apt install fuse-overlayfs


# symlink
sudo ln -vs /usr/bin/podman /usr/local/bin/docker


# docker-compose

sudo curl -L "https://github.com/docker/compose/releases/download/1.29.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose


# podman.sock & link

sudo systemctl start podman.service
sudo systemctl enable podman.socket

sudo ln -sv /run/podman/podman.sock /run/docker.sock
sudo ln -sv /run/podman/podman.sock /var/run/docker.sock

# test
sudo curl -H "Content-Type: application/json" --unix-socket /var/run/docker.sock http://localhost/_ping



# manual edit

echo ""
echo ""
echo ""
echo "Uncomment the following line"
echo "  /etc/containers/storage.conf"
echo "     #mount_program = /usr/bin/fuse-overlayfs"
echo ""

