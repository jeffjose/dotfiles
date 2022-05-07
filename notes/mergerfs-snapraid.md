'# mergerfs



1. Install from github releases

```
wget 'https://github.com/trapexit/mergerfs/releases/download/2.33.5/mergerfs_2.33.5.ubuntu-focal_amd64.deb'
```

2. Create a mountpoint

```
sudo mkdir /mnt/storage
```

3. Find disk UUIDs

```
sudo blkid | tee /tmp/blkid
```

4. Edit fstab

sdh (110G) => OS (ubuntu)
sda (parity, 3.7T), sdb (1.8T), sdc (1.8T), sdd (3.7T), sde (2.7T), sdf(2.7T), sdg (2.7T), sdi (110G) => Disks for mergerfs

```
# MergerFS
# /dev/sda - parity
UUID="2b0df8cc-2134-4fdf-8982-71da198b816a" /mnt/parity ext4 defaults 0 0

# /dev/sdb - disk1
UUID="b2784ff6-ec4b-4978-b8b7-450bd81d0946" /mnt/disk1 ext4 defaults 0 0

# /dev/sdc - disk2
UUID="2b2a5b0e-adf8-4dba-9a6a-af19e1e63e7a" /mnt/disk2 ext4 defaults 0 0

# /dev/sdd - disk3
UUID="8a71d708-f557-4ccb-a7e1-9d0a673f0ae1" /mnt/disk3 ext4 defaults 0 0

# /dev/sde - disk4
UUID="ab2a9e26-7ae2-4b4f-bc6f-80bdd291c501" /mnt/disk4 ext4 defaults 0 0

# /dev/sdf - disk5
UUID="4d3a5031-3851-4c06-9757-9cf93b23b055" /mnt/disk5 ext4 defaults 0 0

# /dev/sdg - disk6
UUID="1fd2e159-7754-4dc7-9d68-75cf71e07633" /mnt/disk6 ext4 defaults 0 0

# [DO NOT USE] /dev/sdh - OS (ubuntu)
# (empty line)

# /dev/sdi - disk7
UUID="2d1a5fbc-10b4-4e96-b239-ed651bd2a9c8" /mnt/disk7 ext4 defaults 0 0

# mergerfs pool
/mnt/disk* /mnt/storage fuse.mergerfs direct_io,defaults,allow_other,minfreespace=50G,fsname=mergerfs 0 0
```


5. Install snapraid
```
sudo apt install snapraid
```

6. Setup snapraid

`/etc/snapraid.conf`

```

# Defines the file to use as parity storage
# FORMAT: "parity FILE_PATH"
parity /mnt/parity/snapraid.parity

# Defines the files to use as content list
# You must have atleast one copy for each parity file plus one.
# They can be in disks used for data, parity or boot,
# but each file must be in a different disk
content /var/snapraid/snapraid.content
content /mnt/disk1/.snapraid.content
content /mnt/disk2/.snapraid.content
content /mnt/disk3/.snapraid.content
content /mnt/disk4/.snapraid.content
content /mnt/disk5/.snapraid.content
content /mnt/disk6/.snapraid.content
content /mnt/disk7/.snapraid.content

# Defines the data disks to use
# The order is relevant for parity, do not change
# FORMAT: "disk DISK_NAME DISK_MOUNT_POINT"
disk d1 /mnt/disk1
disk d2 /mnt/disk2
disk d3 /mnt/disk3
disk d4 /mnt/disk4
disk d5 /mnt/disk5
disk d6 /mnt/disk6
disk d7 /mnt/disk7

# Defines files and directories to exclude
# Remember that all the paths are relative at the mount points
# Format: "exclude FILE"
# Format: "exclude DIR/"
# Format: "exclude /PATH/FILE"
# Format: "exclude /PATH/DIR/"
exclude *.unrecoverable
exclude /tmp/
exclude /lost+found/
exclude *.!sync
exclude .AppleDouble
exclude ._AppleDouble
exclude .DS_Store
exclude ._.DS_Store
exclude .Thumbs.db
exclude .fseventsd
exclude .Spotlight-V100
exclude .TemporaryItems
exclude .Trashes
exclude .AppleDB
exclude *.part

```
