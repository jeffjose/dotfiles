## Notes

- IP - 200.200.0.0/24
- port range - 51823-51830 (might need to expand if there are more devices)

## pfsense

- NAT > Outboun
- WAN, source=192.168.3.0/24, srcport=51823:51830, dest=_, destport=_, NAT=WAN, NATport=\*, STATIC=yes
- NETMAKER, src=any,srcport=_, destination=200.200.0.0/24, destport=_, NO NAT

## GUI

- Setup an **Egress** for 192.168.3.1 through peabody

## Peabody firewall

- disable all firewall

```
$ sudo systemctl disable --now firewalld
```

# Important

- Make sure the wg port on clients is 51823+.
- It is OK for oracle to have 51821 (or 51820, 51822)

##
