## Notes

- IP - 200.200.0.0/24
- port range - 51823-51830 (might need to expand if there are more devices)


## pfsense stuff

- NAT > Outboun
 - WAN, source=192.168.3.0/24, srcport=51823:51830, dest=*, destport=*, NAT=WAN, NATport=*, STATIC=yes
 - NETMAKER, src=any,srcport=*, destination=200.200.0.0/24, destport=*, NO NAT
