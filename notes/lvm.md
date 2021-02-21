# lvm

## Structure

physical volume -> volume groups -> logical volumes

example

- sda -> pve -> data

| command     | notes                    |
| ----------- | ------------------------ |
| `pvdisplay` | Display Physical Volumes |
| `vgdisplay` | Display Volume Groups    |
| `lvdisplay` | Display Logical Volumes  |
| `vgs`       | Display everything       |

## Commands

Create a new logical volume

```bash
sudo lvcreate -l 99%FREE -n $name $vgname
```

optionally convert to thin-pool

```bash
sudo lvconvert  --type thin-pool $vgname/$name
```

format the volume so that we can start using it

```bash
mkfs.ext4 /dev/mapper/$vgname-$name
```
