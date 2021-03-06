#!/bin/bash
#
# Jeffrey Jose
#
# Docker
sudo apt -y remove docker docker-engine docker.io containerd runc
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
#sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu disco stable"
sudo apt update
sudo apt -y install docker-ce docker-ce-cli containerd.io

sudo groupadd docker 2>/dev/null
sudo usermod -aG docker $USER

# Run this manually
#sudo newgrp docker
echo "-----------------------"
echo "Run this manually"
echo "newgrp docker"
echo ""
echo "You might have to log out / log in"
echo "-----------------------"
