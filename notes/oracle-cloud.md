# Steps

1. webui: Create compute instance
2. webui: Expose all ports in the subset (makes it easier for future)
3. host/terminal: open up port
    - 5223 for handshake
    - 80 for traffic


# Export 80/tcp and 80/udp
```
sudo firewall-cmd  --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd  --permanent --zone=public --add-port=80/udp
```

# Reload
```
sudo firewall-cmd  --reload
```
