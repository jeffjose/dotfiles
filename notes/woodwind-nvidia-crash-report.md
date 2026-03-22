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

### Working theories

1. **ACPI/BIOS bug** — the BIOS _DSM error on PEG1.PEGP could be causing the GPU to enter a bad power state. A BIOS update might fix this.
2. **PSU degradation** — even at idle 30W, a failing PSU can drop voltage on the 12V rail momentarily, causing a hard reset. The USB disconnect is a classic PSU symptom.
3. **GPU hardware fault** — the card itself may be failing. A silent hard reset with no Xid is unusual for software issues.

### Next Steps

1. **Check for BIOS update** — the ACPI errors are a known class of BIOS bugs that can affect GPU stability
2. **Run `gpu-burn` stress test** — try to trigger crash under load to see if it's power-related
   ```
   git clone https://github.com/wilicc/gpu-burn
   cd gpu-burn && make
   ./gpu_burn 300   # 5 minute stress test
   ```
3. **Monitor PSU voltages** — check 12V rail stability if possible (BIOS hardware monitor or multimeter)
4. **Try nvidia-driver-580-open** (open kernel module) — different code path, might avoid the ACPI interaction
5. **Try booting with `pci=nocrs`** — kernel parameter to ignore ACPI PCI resource settings, may work around the BIOS bug

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
