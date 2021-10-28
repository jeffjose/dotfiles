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
