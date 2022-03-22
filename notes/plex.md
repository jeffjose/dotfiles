# plex on podman with hardware virt

## proxmox host (hostname: flatbread)
- /etc/default/grub
  GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on video=efifb:off pcie_acs_override=downstream"

- /etc/modules
  vfio
  vfio_iommu_type1
  vfio_pci
  vfio_virqfd

- /etc/modprobe.d/blacklist.conf
  blacklist i915

- /etc/modprobe.d/vfio.conf (get the id from `lspci -nnn | grep vga`)
  options vfio-pci ids=8086:3ea5

- sudo update-grub

## proxmox gui
 - memory = 29G
 - cpu - 8 vcpu
 - bios - seabios
 - machine - i440fx
 - pcidevice - 00:02,x-vga=1

# guest (hostname: funnel)
 - `lspci -nnn | grep vga`
    00:10.0 VGA compatible controller [0300]: Intel Corporation Iris Plus Graphics 655 [8086:3ea5] (rev 01)

    - It used to have a generic VGA device at 00:02. My sense is after blacklisting i915 that went away.
    - We want to have just the Intel Iris at /dev/dri/card0

- `sudo lshw -c video`

- `chmod 777 /dev/dri/card0`
  - This is so that rootless podman can access it

- Disable avahi because of port 5353/udp
  - `sudo systemctl disable --now avahi-daemon.socket && sudo systemctl disable --now avahi-daemon.service`
