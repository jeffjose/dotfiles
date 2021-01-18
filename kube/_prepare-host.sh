#!/bin/bash

echo "[TASK] Install containerd, ca-certificates"
apt update -qq >/dev/null 2>&1
apt install -qq -y containerd apt-transport-https ca-certificates >/dev/null 2>&1
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null 2>&1

echo "[TASK] Enable ssh password auth"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >>/etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1

# Hack required to provision K8s v1.15+ in LXC containers
echo "[TASK] Hack for provisioning k*s v1.15+ in LXC"
mknod /dev/kmsg c 1 11
echo 'mknod /dev/kmsg c 1 11' >>/etc/rc.local
chmod +x /etc/rc.local

# Hack required to provision K8s v1.15+ in LXC containers
echo "[TASK] Restart"
sudo reboot
