- Ensure root@hostname can login
  - Set a password
    - sudo su
    - passwd
  - Change ssh config
    - vi /etc/ssh/sshd_config (AllowRootLogin yes)
    - sudo service ssh restart

- To install k3s server
  - k3up install --ip server_ip --user root

- To install k3s agent
  - k3up join --ip agent_ip --server-ip server_ip --user root

- On server
  - sudo kubectl get node
  - sudo kubectl get node -o wide

