# Woodwind NVIDIA Crash Report

Machine: woodwind (desktop)
GPU: NVIDIA GeForce RTX 3090 (GA102, rev a1)
Motherboard: ASUS ROG Maximus Z690 HERO (BIOS 1720, 2022-08-12) — **17 versions behind, latest is 4505 (2025-12-15)**
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

### Test 1: Clock lock + PCIe runtime PM (2026-03-22) — FAILED

**Clock lock + PCIe runtime PM** — neither persists across reboots:
```
sudo nvidia-smi -lgc 210,210
sudo sh -c 'echo on > /sys/bus/pci/devices/0000:01:00.0/power/control'
```
Result: crashed after ~6.5 hours while watching YouTube on Chrome. Not just an idle issue — also crashes during light GPU use (hardware video decode). Clock lock only locks graphics clocks, not NVDEC.

### Test 2: Kernel parameters (2026-03-22) — ACTIVE

Applied persistent kernel parameters in `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pcie_aspm=off nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_DynamicPowerManagement=0x00"
```
- `pcie_aspm=off` — disables PCIe ASPM entirely. Fixes it for most people alone.
- `nvidia.NVreg_EnableGpuFirmware=0` — disables GSP firmware (known to cause crashes since driver 555+, per ArchWiki)
- `nvidia.NVreg_DynamicPowerManagement=0x00` — disables NVIDIA dynamic power management

These persist across reboots. Rebooted at ~15:37. Monitoring.

**Success criteria:** 3+ days uptime (pre-crash baseline was 7-24 days).

### Test 2 result (2026-03-23)

Kernel params helped (10.5 hours, longest since January) but **still crashed twice overnight**:
- 15:37 → ~02:15 (10.5 hours)
- 02:15 → ~06:33 (4.25 hours)

### Next steps

**Step 1: Update BIOS (highest priority)**

Current BIOS **1720** is from Aug 2022 — 17 versions behind. Latest is **4505** (Dec 2025). The `PEG1.PEGP._DSM` ACPI bug is almost certainly fixed in newer ACPI tables. This board has known GPU issues reported by others (RTX 3090 performance problems, RTX 4090 black screens, broken ASPM).

Update via ASUS EZ Flash:
1. Download BIOS 4505 from [ASUS support page](https://www.asus.com/us/supportonly/rog%20maximus%20z690%20hero/helpdesk_bios/)
2. Copy to USB drive (FAT32)
3. Enter BIOS → Tool → ASUS EZ Flash 3 Utility
4. Select the file and flash

**Note:** BIOS 2004+ introduced rollback restrictions — once updated, you may not be able to downgrade. Back up current BIOS settings first.

**Step 2: Disable ASPM in BIOS (do this during BIOS update)**

Advanced Mode → Platform Misc Configuration:
- **PEG - ASPM**: Disabled (this is the GPU slot — critical one)
- **DMI Link ASPM Control**: Disabled
- **DMI ASPM**: Disabled
- **L1 Substates**: Disabled
- **Native ASPM**: Disabled (prevents OS from controlling ASPM)

**Step 3: Check recall status**

This board has a [CPSC recall](https://www.cpsc.gov/Recalls/2022/ASUS-Computer-International-Recalls-ASUS-ROG-Maximus-Z690-Hero-Motherboards-Due-to-Fire-and-Burn-Hazards) for a reversed capacitor causing shorts/fire. Affected: part `90MB18E0-MVAAY0` with serials starting **MA**, **MB**, or **MC**. Probably not related to idle crashes (causes POST failures), but worth verifying.

**Step 4: Physical checks (if BIOS update doesn't fix it)**

- Reseat GPU and power connectors
- Try a different PCIe slot if available

### Online reports matching this issue

- **ASUS Z690/Z790 boards specifically** have buggy ACPI `_DSM` tables for the GPU PCIe slot — confirmed by user who swapped to ASRock and errors disappeared
- **RTX 3090 on Z690 HERO** — performance halved after BIOS update past 0811 (Tom's Hardware)
- **RTX 4090 on Z690 HERO** — random black screens and freezing (ROG Forum)
- **PCIe ASPM L0s confirmed broken** for NVIDIA GPUs on Intel platforms (NVIDIA Forums, multiple threads)
- Sources:
  - [Xid 79 crash at idle with ASPM L0s](https://forums.developer.nvidia.com/t/nvidia-driver-xid-79-gpu-crash-while-idling-if-aspm-l0s-is-enabled-in-uefi-bios-gpu-has-fallen-off-the-bus/314453)
  - [GPU issue since Z690 Hero BIOS update](https://forums.tomshardware.com/threads/gpu-issue-since-z690-hero-bios-update-please-can-anyone-help-me.3757866/)
  - [Z690 Hero black screens with RTX 4090](https://rog-forum.asus.com/t5/gaming-motherboards/z690-hero-random-but-consistent-black-screens-freezing-only-with/td-p/924789)
  - [Persistent ACPI/_DSM GPU issues on ASUS boards](https://www.linux.org/threads/persistent-acpi-_dsm-gpu-power-and-freezing-issues.55289/)

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
| 2026-03-22 ~15:31 | Crashed after ~6.5 hours while actively watching YouTube. Clock lock + PCIe runtime PM not enough. Also crashed during active use, not just idle. |
| 2026-03-22 15:37 | Applied kernel params: `pcie_aspm=off nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_DynamicPowerManagement=0x00` in GRUB. Rebooted. This is the fix that works for most people online. Persists across reboots. |
| 2026-03-23 ~02:15 | Crashed after ~10.5 hours (longest since Jan, but still crashed). Kernel params alone not enough. |
| 2026-03-23 ~06:33 | Crashed after ~4.25 hours. |
| 2026-03-23 | Identified motherboard: ASUS ROG Maximus Z690 HERO, BIOS 1720 (Aug 2022) — 17 versions behind. Known GPU/ASPM issues on this board. BIOS update to 4505 is top priority next step. |
| 2026-03-25 | Investigated whether BIOS update is a confirmed fix. **It is not.** No one has confirmed that a BIOS update fixes silent hard reboots on this board. One user reports RTX 3090 performance *halved* after updating past BIOS 0811. The ACPI `_DSM` errors are widely described as "usually ignorable." BIOS update carries risk (rollback restricted after 2004). |
| 2026-03-28 | Status check: **14 crashes in 3 days** (Wed 25 → Sat 28). Average uptime 4.8 hours. No improvement. All kernel params still active (`pcie_aspm=off`, GSP off, DPM off). Driver 570.211.01. Still zero log traces before any crash — last entries are always mundane cron/DHCP. No BIOS changes made yet. |
| 2026-03-28 | **memtest86+ v6.10: PASSED.** 13 passes, 0 errors, 10+ hours, CPU 44/49°C. System did NOT crash during memtest. This is critical: 10 hours of heavy CPU+RAM stress with no crash, while Linux crashes every 4.8 hours. **Rules out RAM, CPU, and PSU.** The crash only happens when Linux + NVIDIA driver are loaded. |
| 2026-03-25 06:56 | `systemd` and `udev` auto-upgraded (249.11-0ubuntu3.17 → 249.11-0ubuntu3.19) via unattended-upgrades. udev manages device power management including PCIe. Did not immediately stop crashes (14 more crashes after this). |
| 2026-03-27 06:20 | `bind9` libs upgraded (irrelevant). |
| 2026-03-29 | **Uptime 12h 49m and counting** — longest since January. No changes made in BIOS. No new driver/kernel changes. Only difference: system was fully power-cycled through memtest (which doesn't load NVIDIA drivers) before this boot. The udev upgrade from Mar 25 is the only potentially relevant software change, though it didn't help immediately. Could be coincidence — prior longest session was 10.3 hrs. Monitoring. |

### Crash log (2026-03-25 to 2026-03-28)

| Boot | Start | End | Uptime |
|------|-------|-----|--------|
| 1 | Wed 25 14:18 | Wed 25 21:50 | 7.5 hrs |
| 2 | Wed 25 21:51 | Thu 26 02:27 | 4.6 hrs |
| 3 | Thu 26 02:29 | Thu 26 05:31 | 3.0 hrs |
| 4 | Thu 26 05:33 | Thu 26 09:12 | 3.6 hrs |
| 5 | Thu 26 09:13 | Thu 26 14:05 | 4.9 hrs |
| 6 | Thu 26 14:07 | Thu 26 16:30 | 2.4 hrs |
| 7 | Thu 26 16:31 | Fri 27 02:50 | 10.3 hrs |
| 8 | Fri 27 02:51 | Fri 27 06:24 | 3.5 hrs |
| 9 | Fri 27 06:27 | Fri 27 10:38 | 4.2 hrs |
| 10 | Fri 27 10:40 | Fri 27 12:09 | 1.5 hrs |
| 11 | Fri 27 12:10 | Fri 27 18:28 | 6.3 hrs |
| 12 | Fri 27 18:29 | Sat 28 01:53 | 7.4 hrs |
| 13 | Sat 28 01:54 | Sat 28 04:52 | 3.0 hrs |
| 14 | Sat 28 04:53 | Sat 28 08:57 | 4.1 hrs |

### Current status (2026-03-28)

**Nothing has worked so far.** Kernel params, driver downgrade (570), clock locking, PCIe runtime PM — all tried, all failed. Crashes continue every 3-10 hours with no log trace.

**memtest86+ passed (10 hrs, 0 errors, no crash).** This is the most important data point yet:
- Hardware is fine: RAM, CPU, PSU all survived 10+ hours of heavy stress
- The crash **only happens when Linux + NVIDIA driver are loaded**
- This is definitively a software/firmware issue, not hardware

**What we know now:**
- Not RAM (memtest passed)
- Not CPU (memtest passed)
- Not PSU (memtest stresses power delivery, no crash)
- Not thermal (temps always normal)
- Not driver-specific (crashes on both 580.126.09 and 570.211.01)
- Not kernel-specific (crashes on 6.8.0-90, -101, and -106)
- `pcie_aspm=off` + GSP off + DPM off not enough
- Clock locking + PCIe runtime PM not enough
- Crashes at idle AND during light use (YouTube)
- Zero log trace before any crash

**Remaining options (narrowed):**
1. **Disable ASPM in BIOS** (no flash needed) — kernel param `pcie_aspm=off` may not override firmware-level ASPM. Check Advanced → Platform Misc Config for PEG-ASPM, Native ASPM, L1 Substates
2. **BIOS update to 4505** — the ACPI `_DSM` bug on PEG1.PEGP may be causing the crash even with ASPM "off". 17 versions behind. Risky (rollback restricted after 2004) but increasingly likely to be the fix
3. **Try nouveau driver** — if the crash stops with nouveau, confirms it's the proprietary NVIDIA kernel module
4. **Try nomodeset / headless boot** — boot without GPU driver to confirm stability
5. **Reseat GPU and power connectors** — cheap to try, unlikely to help given memtest passed
