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

# Driver series to install. 610 = newest in jammy-updates/multiverse.
# Anything >= 580 satisfies CUDA 13. Proprietary (not -open) to match the
# previous setup.
TARGET=${TARGET:-610}

echo "=== woodwind: nvidia -> $TARGET ==="
echo
echo "Re-running this script is safe: every step is idempotent."
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
echo "[3/6] apt update + installing nvidia-driver-$TARGET..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  "nvidia-driver-$TARGET"

# --- Step 4: sweep leftovers from every other driver series -----------------
# Sweeps any nvidia package (installed OR 'rc' config-residue) that is not part
# of $TARGET. At first run this caught 2 orphaned nvidia-firmware-580-* plus 9
# 'rc' residues from the March downgrade, and the 4 'rc' residues that the 570
# removal itself leaves behind.
echo
echo "[4/6] Sweeping leftovers from other driver series..."
STALE=$(dpkg-query -W -f='${db:Status-Abbrev}|${Package}\n' 2>/dev/null \
        | awk -F'|' -v t="-$TARGET" \
            '$1 ~ /^(ii|rc)/ && $2 ~ /nvidia/ \
             && $2 ~ /-(4[0-9][0-9]|5[0-9][0-9]|6[0-9][0-9])(-|$)/ \
             && index($2, t) == 0 {print $2}')
# The series pattern must be anchored with (-|$): a looser /-[0-9][0-9][0-9]/
# also matches linux-signatures-nvidia-6.8.0-138-generic via the kernel
# version, which must NOT be purged.
if [[ -n "$STALE" ]]; then
  echo "$STALE" | sed 's/^/  /'
  # shellcheck disable=SC2086
  sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y $STALE
else
  echo "  (nothing left to sweep)"
fi
sudo apt-get autoremove -y

# --- Step 5: repair the nvidia-persistenced user, then verify ----------------
# dpkg ordering hazard: nvidia-compute-utils-<new>.postinst creates the
# 'nvidia-persistenced' system user, but nvidia-compute-utils-<old>.postrm runs
# `userdel nvidia-persistenced` and may execute AFTER it. The user then vanishes
# and nvidia-persistenced.service fails with:
#   ERROR: Failed to find user ID of user 'nvidia-persistenced': Success
# Re-running the postinst after the sweep restores it. Idempotent.
echo
echo "[5/6] Checking the nvidia-persistenced user..."
if getent passwd nvidia-persistenced > /dev/null; then
  echo "  user present"
else
  echo "  user MISSING (known dpkg ordering hazard) -- reconfiguring..."
  sudo dpkg-reconfigure "nvidia-compute-utils-$TARGET"
  getent passwd nvidia-persistenced > /dev/null \
    && echo "  user restored" || echo "  STILL MISSING -- investigate"
fi
sudo systemctl restart nvidia-persistenced || true
systemctl is-active nvidia-persistenced \
  && echo "  nvidia-persistenced: active" \
  || echo "  nvidia-persistenced: NOT active -- check 'systemctl status'"

echo
echo "DKMS status (expect nvidia/$TARGET.* for $(uname -r)):"
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
echo "    nvidia-smi                 # expect Driver $TARGET.x, CUDA Version 13.x"
echo "    cat /proc/cmdline          # crash-era params should be gone"
echo
echo "Then start ComfyUI -- the cu130 torch should initialize."
echo
echo "Rollback if needed: sudo apt install nvidia-driver-570 && restore"
echo "  /root/grub.bak.$STAMP -> /etc/default/grub && sudo update-grub && reboot"
