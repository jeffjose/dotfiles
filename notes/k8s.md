1. Change vm.swappines for k8s

  $ sudo vi /etc/sysctl.conf
    - vm.swappiness = 0

  $ sudo sysctl -p

  $ sudo reboot

2. Also change swap to 0 for the vms/containers
