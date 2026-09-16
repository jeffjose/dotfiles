#!/bin/bash
set -euo pipefail

# 2026-09-15: Upgrade nvidia-driver 570.211.01 -> 610.57.04 and undo the
# crash-era workarounds.
#
# WHY THIS IS SAFE NOW:
#   The 570 pin was set 2026-03-21 while chasing silent hard resets on woodwind.
#   Per ~/dotfiles/notes/woodwind-nvidia-crash-report.md (2026-07-18), the root
#   cause was CONFIRMED to be the Seasonic PRIME 1200W PSU heat-soaking at idle
#   with its semi-passive fan stopped. Fix = Hybrid Mode button OFF. Test 4
#   crashed with the NVIDIA stack fully removed, so the driver was conclusively
#   exonerated. The pin and the GRUB params below all protect against theories
#   that are now closed.
#
# WHY UPGRADE: ComfyUI Desktop pins torch==2.12.1+cu130 (CUDA 13.0), which
#   needs a 580+ driver. 570 exposes CUDA 12.8 -> "driver is too old (12080)".
#
# DO NOT TOUCH: the PSU Hybrid Mode button must stay OFF (button out/up).
#   That is the actual fix and this script does not affect it.

echo "=== woodwind: nvidia 570 -> 610 ==="
echo

STAMP=$(date +%Y%m%d-%H%M%S)

# --- Step 1: remove the 570 apt pin -----------------------------------------
echo "[1/6] Removing the 570 apt pin..."
if [[ -f /etc/apt/preferences.d/nvidia-pin ]]; then
  sudo cp -av /etc/apt/preferences.d/nvidia-pin "/root/nvidia-pin.bak.$STAMP"
  sudo rm -v /etc/apt/preferences.d/nvidia-pin
else
  echo "  (already gone)"
fi

# --- Step 2: drop the crash-era GRUB workaround params ----------------------
# pcie_aspm=off                        -> ASPM ruled out 2026-06-06
# nvidia.NVreg_EnableGpuFirmware=0     -> GSP disable; unsupported on modern
#                                         drivers, must not ride onto 610
# nvidia.NVreg_DynamicPowerManagement=0x00 -> GPU power mgmt workaround
echo
echo "[2/6] Cleaning crash-era kernel params from GRUB..."
sudo cp -av /etc/default/grub "/root/grub.bak.$STAMP"
sudo sed -i -E \
  -e 's/ ?pcie_aspm=off//' \
  -e 's/ ?nvidia\.NVreg_EnableGpuFirmware=0//' \
  -e 's/ ?nvidia\.NVreg_DynamicPowerManagement=0x00//' \
  /etc/default/grub
echo "  now: $(grep '^GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub)"
sudo update-grub

# --- Step 3: install 610 ----------------------------------------------------
echo
echo "[3/6] apt update + installing nvidia-driver-610..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  nvidia-driver-610

# --- Step 4: sweep the stale 580 leftovers ----------------------------------
# The 570 stack is removed automatically by the 610 install above, so this only
# sweeps what that leaves behind:
#   - 2 orphaned nvidia-firmware-580-* packages (still fully installed; the
#     crash report flagged these back in March)
#   - 9 'rc' config residues from the March 580 -> 570 downgrade
echo
echo "[4/6] Sweeping stale 580 leftovers..."
STALE=$(dpkg-query -W -f='${db:Status-Abbrev}|${Package}\n' 2>/dev/null \
        | awk -F'|' '$1 ~ /^(ii|rc)/ && $2 ~ /nvidia/ && $2 ~ /-580/ {print $2}')
if [[ -n "$STALE" ]]; then
  echo "$STALE" | sed 's/^/  /'
  # shellcheck disable=SC2086
  sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y $STALE
else
  echo "  (nothing left to sweep)"
fi
sudo apt-get autoremove -y

# --- Step 5: verify the module built ----------------------------------------
echo
echo "[5/6] DKMS status (expect nvidia/610.* for $(uname -r)):"
dkms status || true
echo
echo "Installed driver packages:"
dpkg -l | grep -E "^ii.*nvidia-driver" | awk '{print "  " $2, $3}'

# --- Step 6: reboot ---------------------------------------------------------
echo
echo "[6/6] Done. A REBOOT is required (the running kernel still has 570 loaded)."
echo
echo "    sudo reboot"
echo
echo "After reboot, verify:"
echo "    nvidia-smi                 # expect Driver 610.x, CUDA Version 13.x"
echo "    cat /proc/cmdline          # crash-era params should be gone"
echo
echo "Then start ComfyUI -- the cu130 torch should initialize."
echo
echo "Rollback if needed: sudo apt install nvidia-driver-570 && restore"
echo "  /root/grub.bak.$STAMP -> /etc/default/grub && sudo update-grub && reboot"
