## Browsers fail but curl works

- curl works fine, browsers timeout
- Network-specific (BT WiFi PPPoE)
- Cause: Path MTU < 1420, large packets dropped

Debug:
```
$ ping -M do -s 1392 google.com  # fails = MTU issue
```

Fix - add to `/etc/wireguard/wg0.conf`:
```
[Interface]
MTU = 1280
...
```

Quick test:
```
$ sudo ip link set wg0 mtu 1280
```
