# Woodwind NVIDIA Crash Report

Machine: woodwind (desktop)
GPU: NVIDIA GeForce RTX 3090 (GA102, rev a1)
OS: Ubuntu 22.04 (jammy), HWE kernel

---

## 2026-03-21: Investigation

### Symptom

System crashing and hard-rebooting every 6-18 hours. No kernel panic logged, no Xid errors, no MCE — just silent hard reset. 80 reboots recorded in wtmp, only 6 were clean shutdowns.

### Root Cause

NVIDIA driver auto-upgraded from `580.95.05` → `580.126.09` on **2026-01-29** via unattended-upgrades. Crashes started immediately.

### Evidence

| Period | Kernel | NVIDIA Driver | Typical Uptime |
|--------|--------|---------------|----------------|
| Dec 11 - Jan 29 | 6.8.0-90 | 580.95.05 | 7-24 days |
| Jan 29 - Feb 28 | 6.8.0-90 | **580.126.09** | 6-24 hours |
| Feb 28 - Mar 16 | 6.8.0-101 | 580.126.09 | 6-18 hours |
| Mar 16 - present | 6.8.0-106 | 580.126.09 | 6-18 hours |

- Before Jan 29: uptimes of 7, 18, 24 days. Stable.
- After Jan 29: never lasted more than ~18 hours. First crash was 1.5 hours after driver upgrade.
- Kernel upgrades to 101 and 106 did not help — problem is the driver, not the kernel.
- Crash leaves no trace in logs (dmesg, syslog, journalctl). Last logged entries before each crash are mundane (cron jobs, DHCP renewals, screensaver). This is consistent with an NVIDIA kernel module fault that hard-resets before anything can flush to disk.
- Temperatures are normal (CPU 23-28°C, GPU 37°C). No MCE/memory errors. No OOM. Not a thermal or hardware issue.

### What was tried before (didn't help)

- Kernel upgraded 6.8.0-90 → 6.8.0-101 (Feb 28)
- Kernel upgraded 6.8.0-101 → 6.8.0-106 (Mar 16)

### Next Steps

1. **Switch to nvidia-driver-570** (version 570.211.01)
   - Prebuilt kernel modules exist for 6.8.0-106 — no kernel change needed
   - CUDA drops from 13.0 → 12.8 (fine for ollama and general use)
   - RTX 3090 fully supported
   ```
   sudo apt install nvidia-driver-570
   sudo reboot
   ```

2. **Monitor uptime** — if 3+ days without a crash, confirmed fixed (pre-upgrade baseline was 7-24 days)

3. **Pin the driver** to prevent unattended-upgrades from breaking it again:
   ```
   # /etc/apt/preferences.d/nvidia-pin
   Package: nvidia-driver-*
   Pin: version 570.*
   Pin-Priority: 1001
   ```

4. **If 570 also crashes** — suspect hardware (PSU under load, GPU itself). Next steps would be:
   - Run `gpu-burn` stress test to try to reproduce under load
   - Check PSU voltages
   - Try nvidia-driver-590 or the open kernel module variant (nvidia-driver-580-open)
