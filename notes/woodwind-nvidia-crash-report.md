# Woodwind NVIDIA Crash Report

Machine: woodwind (desktop)
GPU: NVIDIA GeForce RTX 3090 (GA102, rev a1)
OS: Ubuntu 22.04 (jammy), HWE kernel

---

## 2026-03-21: Investigation

### Symptom

System crashing and hard-rebooting every 6-18 hours. No kernel panic logged, no Xid errors, no MCE — just silent hard reset. 80 reboots recorded in wtmp, only 6 were clean shutdowns.

### Root Cause

**Still under investigation.** Initially suspected NVIDIA driver `580.126.09` (auto-upgraded on 2026-01-29 via unattended-upgrades), but downgrading to `570.211.01` did not fix the crashes. Now suspecting hardware (PSU, GPU, or PCIe/ACPI interaction).

### Evidence

| Period | Kernel | NVIDIA Driver | Typical Uptime |
|--------|--------|---------------|----------------|
| Dec 11 - Jan 29 | 6.8.0-90 | 580.95.05 | 7-24 days |
| Jan 29 - Feb 28 | 6.8.0-90 | **580.126.09** | 6-24 hours |
| Feb 28 - Mar 16 | 6.8.0-101 | 580.126.09 | 6-18 hours |
| Mar 16 - Mar 21 | 6.8.0-106 | 580.126.09 | 6-18 hours |
| Mar 21 - present | 6.8.0-106 | **570.211.01** | ~2.75 hours (crashed) |

- Before Jan 29: uptimes of 7, 18, 24 days. Stable.
- After Jan 29: never lasted more than ~18 hours. First crash was 1.5 hours after driver upgrade.
- Kernel upgrades to 101 and 106 did not help — problem is the driver, not the kernel.
- Crash leaves no trace in logs (dmesg, syslog, journalctl). Last logged entries before each crash are mundane (cron jobs, DHCP renewals, screensaver). This is consistent with an NVIDIA kernel module fault that hard-resets before anything can flush to disk.
- Temperatures are normal (CPU 23-28°C, GPU 37°C). No MCE/memory errors. No OOM. Not a thermal or hardware issue.

### What was tried before (didn't help)

- Kernel upgraded 6.8.0-90 → 6.8.0-101 (Feb 28)
- Kernel upgraded 6.8.0-101 → 6.8.0-106 (Mar 16)

### Fix Applied

1. ~~**Switch to nvidia-driver-570**~~ — **Done (2026-03-21)**
   - Installed `nvidia-driver-570` (version 570.211.01)
   - CUDA 12.8 (down from 13.0, fine for ollama and general use)
   - Kernel unchanged: 6.8.0-106

2. ~~**Pin the driver**~~ — **Done (2026-03-21)**
   - `/etc/apt/preferences.d/nvidia-pin` in place, pinning `nvidia-driver-*` to `570.*` at priority 1001

### Clues from crash investigation (2026-03-21 evening)

- **Driver 570 also crashes** — crashed after ~2.75 hours. Rules out driver 580.126.09 as sole cause.
- **Still no trace in logs** — last entries before crash are cron jobs and DHCP renewals. Nothing from NVIDIA or kernel.
- **ACPI BIOS errors on GPU PCIe slot every boot:**
  ```
  ACPI BIOS Error (bug): Failure creating named object [\_SB.PC00.PEG1.PEGP._DSM.USRG], AE_ALREADY_EXISTS
  ACPI Warning: \_SB.PC00.PEG1.PEGP._DSM: Argument #4 type mismatch - Found [Buffer], ACPI requires [Package]
  ```
  PEG1.PEGP is the GPU's PCIe slot. The BIOS has a buggy _DSM method for this device. Could be interfering with GPU power management.
- **USB disconnect ~2 hours before crash** — `usb 1-2` disconnected at 19:47, crash at ~21:39. Could indicate power instability.
- **Temps are fine** — GPU 31°C, CPU 21-24°C, NVMe 33-38°C. Not thermal.
- **No HW throttling** — no HW Slowdown, no HW Power Brake, no thermal slowdown active.
- **GPU drawing only ~30W at idle** (limit 350W) — crash is happening at idle, not under load.
- **User reports crashes almost always happen when away from the computer** — overnight, or when idle for a while. Only crashed once or twice during active use (light work: Chrome, VS Code, webdev). GPU is never pushed hard. This strongly suggests the crash is triggered by **GPU idle power state transitions** (P8 → deeper states), not by load.

### Working theories

**This is a known issue.** Widely reported across NVIDIA forums, Arch wiki, Ubuntu communities. The exact symptom — silent hard reset at idle, no Xid, no kernel panic — is the classic **"GPU has fallen off the bus" (Xid 79)** problem caused by PCIe ASPM (Active State Power Management). The GPU's PCIe link enters a low-power state (L0s/L1) and fails to wake, taking the whole system down before anything can log. The ACPI BIOS bug on PEG1.PEGP makes it worse by mishandling the power state transitions.

**Not a hardware issue.** GPU and PSU are almost certainly fine. It's a software/firmware interaction between Linux, NVIDIA driver, and the motherboard BIOS.

Key sources:
- [Xid 79 GPU crash while idling if ASPM L0s enabled](https://forums.developer.nvidia.com/t/nvidia-driver-xid-79-gpu-crash-while-idling-if-aspm-l0s-is-enabled-in-uefi-bios-gpu-has-fallen-off-the-bus/314453)
- [XID 79 happens on idle only](https://forums.developer.nvidia.com/t/xid-79-gpu-has-fallen-off-the-bus-happens-on-idle-only/323332)
- [GPU falls off bus when idle, displays powered off](https://forums.developer.nvidia.com/t/gpu-has-fallen-off-the-bus-while-idle-only-occurs-when-all-displays-powered-off/203096)
- [Solved: GPU fallen off bus - Arch Forums](https://bbs.archlinux.org/viewtopic.php?id=304020)
- [NVIDIA/Troubleshooting - ArchWiki](https://wiki.archlinux.org/title/NVIDIA/Troubleshooting)

### Current test (2026-03-22)

**Clock lock + PCIe runtime PM** — neither persists across reboots:
```
sudo nvidia-smi -lgc 210,210
sudo sh -c 'echo on > /sys/bus/pci/devices/0000:01:00.0/power/control'
```
If stable 3+ days → make permanent, then back off one at a time to isolate.

### If current test fails — next steps

**Step 1: Kernel parameters (most effective fix reported by others)**

Add to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`:
```
pcie_aspm=off nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_DynamicPowerManagement=0x00
```
Then:
```
sudo update-grub && sudo reboot
```
- `pcie_aspm=off` — disables PCIe ASPM entirely. Fixes it for most people alone.
- `nvidia.NVreg_EnableGpuFirmware=0` — disables GSP firmware (known to cause crashes since driver 555+, per ArchWiki)
- `nvidia.NVreg_DynamicPowerManagement=0x00` — disables NVIDIA dynamic power management

**Step 2: Disable ASPM in BIOS/UEFI**

Look for settings like:
- "PEG 0/1 ASPM: Disabled"
- "PCIe ASPM Support: Disabled"
- "Native ASPM: Enabled" (lets OS control, combined with kernel `pcie_aspm=off`)

**Step 3: BIOS update**

The `PEG1.PEGP._DSM` ACPI error is a motherboard BIOS bug. Check for a newer BIOS version.

**Step 4: Physical checks (unlikely needed)**

- Reseat GPU and power connectors
- Try a different PCIe slot if available

---

## Log

| Date | Event |
|------|-------|
| 2026-01-29 | nvidia-driver auto-upgraded 580.95.05 → 580.126.09 via unattended-upgrades. Crashes begin. |
| 2026-02-28 | Kernel upgraded 6.8.0-90 → 6.8.0-101. Crashes continue. |
| 2026-03-16 | Kernel upgraded 6.8.0-101 → 6.8.0-106. Crashes continue. |
| 2026-03-21 | Investigation. Root cause identified as driver 580.126.09. |
| 2026-03-21 | Downgraded to nvidia-driver-570 (570.211.01). Apt pin set. Rebooted. Monitoring. |
| 2026-03-21 | Crashed again after ~2.75 hours on driver 570. Driver downgrade did NOT fix it. |
| 2026-03-21 | Investigation: ACPI BIOS errors on GPU PCIe slot (PEG1.PEGP), USB disconnects before crash, no Xid/MCE/thermal issues. Suspect hardware (PSU/BIOS/GPU). |
| 2026-03-21 | User confirms crashes almost always when idle/away. Rarely during active use. Points to GPU idle power state transition as trigger. |
| 2026-03-21 22:05 | Locked GPU clocks to 210 MHz (`nvidia-smi -lgc 210,210`) to prevent deep idle power states. Drawing ~38W. Monitoring for crashes. Note: does not persist across reboots. |
| 2026-03-22 ~04:49 | Crashed after ~6.75 hours (clock lock was active for ~5h of that). Longer than usual but still crashed. Clock lock alone is not enough. |
| 2026-03-22 ~09:08 | Crashed after ~4.25 hours. Clock lock did NOT persist across the 04:49 reboot. |
| 2026-03-22 09:34 | Found PCIe runtime PM set to `auto` for GPU (`/sys/bus/pci/devices/0000:01:00.0/power/control`). This lets the PCIe link sleep independently of GPU clocks — likely the missing factor. Also found stale nvidia-firmware-580 packages still installed (not harmful but should clean up). |
| 2026-03-22 | **Test: clock lock + PCIe runtime PM.** `nvidia-smi -lgc 210,210` + `echo on > .../power/control`. Neither persists across reboots. If stable 3+ days, make permanent and then back off one at a time to isolate. |
