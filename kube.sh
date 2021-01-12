#!/bin/bash
#
# Kubernetes
#
# Jan 11, 2021

# k3sup
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/

# helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
