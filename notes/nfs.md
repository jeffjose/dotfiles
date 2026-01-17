# nfs

1. chown not working

```
# replace all_squash with no_root_squash
$ sudo vi /etc/exports

$ exportfs -r

```

2. Mount nfs on windows

```
$ mount ip_address:/nfs/folder P:
```

3. NFS server

```
sudo apt install nfs-kernel-server

# Noone is owner
sudo chown nobody:nogroup /mnt/storage

# Everyone can modify
sudo chmod 777 /mnt/storage
```

Edit /etc/exports

```
/mnt/storage/dir1 *(rw,sync,no_root_squash,no_subtree_check)
/mnt/storage/dir2 *(rw,sync,no_root_squash,no_subtree_check)
```

4. Automount (avoid slow boot when NFS unavailable)

```
# /etc/fstab - use automount instead of mounting at boot
server:/mnt/storage/share /mnt/local/share nfs noauto,x-systemd.automount,x-systemd.mount-timeout=10s,_netdev,timeo=15 0 0

$ sudo systemctl daemon-reload
```

Mounts on first access, not at boot. Times out in 10s if unreachable.
