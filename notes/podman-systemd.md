## Generate a unit file
```
sudo podman generate systemd --new --name plex | sudo tee /etc/systemd/system/plex.service
```

### Start
```
sudo systemctl enable plex
sudo systemctl start plex
```

- Remember to have the container ready (start-plex.sh) and start it atleast once before step1 (generate unit file)
