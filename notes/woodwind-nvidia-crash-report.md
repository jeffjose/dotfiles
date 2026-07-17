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

### 2026-04-25: One month later — no progress

Four weeks since last test. Pattern is unchanged.

**State of the machine (this morning):**
- Kernel: **6.8.0-110** (auto-upgraded from -106 since last entry; did not help)
- Driver: 570.211.01 (still pinned via `/etc/apt/preferences.d/nvidia-pin`)
- BIOS: **still 1720** (Aug 2022) — never updated
- Kernel params: still `pcie_aspm=off nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_DynamicPowerManagement=0x00`
- Stale `nvidia-firmware-580` packages (580.95.05, 580.126.09) **still installed** (low priority but not cleaned up since 2026-03-22)

**Crash cadence (last 5 days):**

| Day | Reboots | Avg uptime |
|-----|---------|-----------|
| Apr 21 | 5 | 3.6 hrs |
| Apr 22 | 7 | 3.4 hrs |
| Apr 23 | 5 | 4.4 hrs |
| Apr 24 | 5 | 4.6 hrs |
| Apr 25 (to 11:20) | 5 | 2.5 hrs |

**25 unclean reboots in 5 days. Avg ~3.7 hrs uptime.** No `shutdown` records in this window — every reboot is a silent hard reset. (Total wtmp: 224 reboots all-time, only **5 clean shutdowns ever** — last clean shutdown was 2026-03-28.)

**No new log signatures.** The PEG1.PEGP `_DSM.USRG` ACPI error still fires at every boot — same wording, same offset:
```
ACPI BIOS Error (bug): Failure creating named object [\_SB.PC00.PEG1.PEGP._DSM.USRG], AE_ALREADY_EXISTS
ACPI Error: Aborting method \_SB.PC00.PEG1.PEGP._DSM due to previous error
```
Crashes still leave zero trace before reset.

**What this rules in:** Everything software-side has been ruled out. The only un-tried levers are firmware/physical:
1. Disable ASPM in BIOS firmware itself (kernel `pcie_aspm=off` is a hint, not a guarantee against firmware-controlled ASPM). **Free, reversible, no flash.**
2. BIOS update 1720 → 4505 (17 versions of fixes; the smoking gun is still in dmesg).
3. Diagnostic: boot once on `nouveau` to confirm whether the proprietary NVIDIA kmod is the actual trigger vs. raw BIOS/ACPI.
4. Reseat GPU / try alternate PCIe slot.

Order of operations: (1) → (3) for free data → (2) if still crashing.

---

## 2026-06-06: ASPM conclusively ruled out — live diagnostics

Six weeks later. Still crashing, **now worse**. Live diagnostics finally answer the open question from 04-25 step 1 ("is `pcie_aspm=off` actually being honored?"). It is — and ASPM is not the cause.

**State of the machine:**
- Kernel: **6.8.0-124** (auto-upgraded from -110; no help)
- Driver: 570.211.01 (still pinned)
- BIOS: **still 1720** (Aug 2022) — never updated
- Kernel params: unchanged (`pcie_aspm=off nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_DynamicPowerManagement=0x00`)

**Crash cadence (from `last reboot`):**
- Jun 6: ~9 hard resets (17:20, 14:49, 10:28, 07:54, 06:24, 04:55, 03:41, 02:04, 00:15) — intervals ~1.5–2.5 hr
- Jun 5: 6+ resets (21:39, 15:40, 12:08, 09:41, 06:43, 04:28)
- **Zero clean shutdowns since wtmp begins (May 17).** Avg uptime now ~1.5–2.5 hr — *worse* than the ~3.7 hr seen in April.

**ASPM is genuinely OFF — ruled out as the cause.** `sudo lspci -vv`:
```
# GPU endpoint 0000:01:00.0
LnkCap:    ... ASPM L0s L1, Exit Latency L0s <512ns, L1 <16us
LnkCtl:    ASPM Disabled; RCB 64 bytes, CommClk+
L1SubCtl1: PCI-PM_L1.2- PCI-PM_L1.1- ASPM_L1.2- ASPM_L1.1-   # all L1 substates off
# upstream root port 0000:00:01.0
LnkCap:    ... ASPM not supported
LnkCtl:    ASPM Disabled
```
The endpoint has ASPM disabled, all L1 substates disabled, AND the upstream root port reports **"ASPM not supported"** — the link physically cannot enter ASPM. Link is healthy (16GT/s x16, no degradation). **This kills the entire ASPM / "GPU fell off the bus due to L0s/L1" working theory that drove 03-21 through 04-25.** The kernel param was being honored all along; it never mattered.

Corollary: the 04-25 "step 1" (disable PEG/per-slot ASPM in BIOS) is now **pointless** — ASPM is already off at every level. Don't waste a reboot on it.

**The `_DSM` ACPI bug is still firing this boot** (and is NOT ASPM — it's the GPU slot's power-management method, i.e. RTD3/GC6 runtime power transitions):
```
[ 9.525810] ACPI Warning: \_SB.PC00.PEG1.PEGP._DSM: Argument #4 type mismatch - Found [Buffer], ACPI requires [Package]
[ 9.722052] ACPI BIOS Error (bug): Failure creating named object [\_SB.PC00.PEG1.PEGP._DSM.USRG], AE_ALREADY_EXISTS
[ 9.722071] ACPI Error: Aborting method \_SB.PC00.PEG1.PEGP._DSM due to previous error
```
GPU `power/runtime_status = active`, `power/control = auto`.

**Revised conclusion.** With ASPM off and still crashing, the remaining firmware suspect is the broken `_DSM` method (governs GPU runtime power-down/resume). A broken `_DSM` mishandling a GPU power transition is fully consistent with "GPU drops silently, hard reset, zero log trace." Only a BIOS update can fix a broken `_DSM` — so the **BIOS flash 1720 → 4505 is now the #1 lever**, not #3.

**Revised order of operations:**
1. **BIOS flash 1720 → 4505** — only thing that can fix the `_DSM` ACPI bug. (Caveats: 4505 has mixed stability reports online; rollback locked after BIOS 2004 — back up settings first.)
2. **nouveau diagnostic boot** — one boot on the open driver. If it stays up, confirms the proprietary kmod's power handling (interacting with the broken `_DSM`) is the trigger. Free, high-information.
3. **Force GPU runtime PM off persistently** — udev rule writing `power/control = on` (tried manually 03-22, never persisted).
4. ~~Disable PEG/ASPM in BIOS~~ — dropped; ASPM already confirmed off at every level.

**New online findings (June 2026 search):**
- **No public fix exists.** Still an open, unsolved class of bug across all 2026 NVIDIA branches (570, 580.119, 580.142, 590.x, 595.x). Driver **595 on Ubuntu 26.04 (May 2026) crashes identically** with Xid 79 on an ASUS board — confirming a newer driver is NOT the answer. Staying pinned on 570 is fine.
- ASUS ROG forum thread *"No Native ASPM support on Asus Z690 Maximus Hero"*: on this exact board "Native ASPM" set to Enable silently reverts to Auto. (Less relevant now that ASPM is confirmed off anyway, but documents the board's flaky ASPM firmware.)
- BIOS 4505 has mixed reports — some stable, some report instability/game crashes on sibling Z690/Z790 boards and reverted. Update with eyes open.
- Sources:
  - [GPU fallen off bus, Ubuntu 26.04, driver 595, ASUS (May 2026)](https://forums.developer.nvidia.com/t/gpu-has-fallen-off-the-bus-within-minutes-of-boot-ubuntu-26-04-595-driver-asus-prime-5070/369604)
  - [Xid 79 during Firefox WebRTC, RTX 3090, 580.142 (Mar 2026)](https://forums.developer.nvidia.com/t/xid-79-gpu-falls-off-bus-during-firefox-webrtc-webcam-session-rtx-3090-580-142-kde-wayland/364961)
  - [No Native ASPM support on Asus Z690 Maximus Hero — ROG Forum](https://rog-forum.asus.com/t5/intel-700-600-series/no-native-aspm-support-on-asus-z690-maximus-hero/td-p/1111024)
  - [BIOS 4505 Z690 Hero — mixed stability reports](https://rog-forum.asus.com/t5/intel-700-600-series/bios-4505-z690-hero/td-p/1130489)

### Procedures (ready to run — NOT yet done as of 2026-06-06)

Safest → riskiest. Do in order; each is reversible except the BIOS flash.

**Procedure A — Force GPU runtime PM off (udev rule). Zero risk, pure software.**

Targets the now-prime suspect: `power/control=auto` lets the kernel runtime-suspend the GPU through the broken `_DSM` path. Pin it `on` so it persists across reboots (manual `echo on` never stuck before).
```sh
echo 'ACTION=="add", SUBSYSTEM=="pci", DRIVER=="nvidia", ATTR{power/control}="on"' \
  | sudo tee /etc/udev/rules.d/80-nvidia-no-runtime-pm.rules
sudo reboot
# verify after reboot:
cat /sys/bus/pci/devices/0000:01:00.0/power/control   # should now read: on
```
Revert: `sudo rm /etc/udev/rules.d/80-nvidia-no-runtime-pm.rules && sudo reboot`
Success criteria: 3+ days uptime.

**Procedure B — nouveau diagnostic boot. Zero brick risk, fully reversible.**

One data point: does the machine stop hard-resetting on the open driver? If yes → cause is the proprietary kmod + `_DSM` interaction, and the BIOS flash is justified. (nouveau on Ampere is slow/rough — diagnostic only.)
```sh
# 1. blacklist the proprietary driver
printf 'blacklist nvidia\nblacklist nvidia_drm\nblacklist nvidia_modeset\nblacklist nvidia_uvm\n' \
  | sudo tee /etc/modprobe.d/blacklist-nvidia.conf
# 2. un-blacklist nouveau (Ubuntu's nvidia packages disable it)
grep -rl nouveau /etc/modprobe.d/ /lib/modprobe.d/ 2>/dev/null   # find the file(s) that blacklist nouveau
#    edit each hit and comment out the "blacklist nouveau" / "options nouveau modeset=0" line
# 3. remove nvidia-drm.modeset / nvidia params from GRUB if present, then:
sudo update-initramfs -u
sudo update-grub
sudo reboot
glxinfo | grep -i "opengl renderer"   # confirm it says "NV..." / nouveau, not NVIDIA
```
Revert: `sudo rm /etc/modprobe.d/blacklist-nvidia.conf`, restore the nouveau-blacklist line(s), `sudo update-initramfs -u && sudo reboot`. Worst case (black screen): boot the previous kernel / recovery mode and revert — nothing was written to firmware.

**Procedure C — BIOS flash 1720 → 4505. LAST RESORT. Small but real brick risk; one-way (rollback locked after 2004).**

Only firmware fix for the broken `_DSM`. Use **BIOS FlashBack** (rear-I/O button) — safest method, doesn't depend on a successful boot, very brick-resistant. Do NOT use EZ Flash if FlashBack is available.
1. Back up current BIOS settings / note XMP + key values first.
2. Download BIOS 4505 from the [ASUS support page](https://www.asus.com/us/supportonly/rog%20maximus%20z690%20hero/helpdesk_bios/).
3. Rename per ASUS FlashBack instructions (BIOSRenamer tool / `M16H.CAP`), put on a FAT32 USB stick.
4. Insert into the dedicated FlashBack USB port, press the FlashBack button, wait for the LED to finish blinking. **Do not cut power.** Use a UPS if available.
Caveat: 4505 has mixed stability reports on sibling Z690/Z790 boards; one report of RTX 3090 perf halved past BIOS 0811. Update with eyes open.

---

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

## 2026-07-16: Fresh analysis — theory revised to low-load power delivery failure (likely PSU)

Five weeks since last entry. Crashes continue and are still worsening. New live diagnostics overturn the working theory.

**State of the machine:**
- Kernel: 6.8.0-124, driver 570.211.01 (pinned), BIOS still 1720
- Kernel params unchanged (`pcie_aspm=off`, GSP off, DPM off)
- Microcode is NOT stale despite old BIOS: OS early-loads `0x3e` (current, intel-microcode 3.20260210) over BIOS's `0x23`
- Procedures A/B/C from 06-06: **none were done** (`power/control` still `auto`, nvidia still loaded, BIOS still 1720)
- wtmp now records **483 reboots**

**New evidence (live, this session):**

1. **Crash cadence is now metronomic and NOT idle-correlated.** Last 76 boots: mean uptime **2.41 h, median 2.24 h, stdev 0.96 h** (min 0.79, max 6.2). Distribution is tightly clustered at 2–3 h, at all hours, including midday active use. The "only crashes when away/idle" pattern from March is gone (or was never the right frame).
   ```
   0-1h: ###   (3)
   1-2h: ###################### (22)
   2-3h: ################################### (35)
   3-4h: ########### (11)
   4-5h: ####  (4)
   6-7h: #     (1)
   ```
2. **Death is instantaneous.** journald writes until <5 s before every reset (a code-tunnel 5-second polling loop is the last entry in every crashed boot). No wind-down, no gap, no kernel message — the platform just stops.
3. **Still zero Xid ever** (two apparent "xid" journal hits since Jul 1 are base64 image blobs in code-tunnel HTML — false positives). Zero MCE, zero PCIe AER, across 483 reboots. No hardware watchdog is armed (no iTCO/wdt module, systemd watchdog disabled) — not a watchdog reset.
4. **GPU runtime PM never engages.** `runtime_status=active`, `runtime_suspended_time=0` all boot, GPU sits at P8 / ~24 W / 210 MHz. This means **the broken `_DSM` method is never exercised at runtime** — it only aborts once during boot-time ACPI parse. The 06-06 conclusion ("BIOS flash to fix `_DSM` is the #1 lever") is substantially weakened: `_DSM` can't be crashing a machine on a code path that never runs.
5. **Deep package idle is constant regardless of activity.** cpu0 this boot: C10 entered 219k times, ~97% residency — *during an active desktop session*. From the power-delivery side, this machine is "idle" 24/7. So the memtest result and the "crashes during YouTube" result stop being contradictory (see below).

**Revised theory: progressive low-load power-delivery failure — PSU is the prime suspect (board VRM second).**

The one pattern no software theory explains is the **monotonic degradation on frozen software**:

| Period | Typical uptime |
|--------|---------------|
| pre-Jan 2026 | 7–24 days |
| Feb–Mar | 6–18 h |
| Mar 25–28 | 4.8 h |
| Apr 21–25 | 3.7 h |
| Jun 5–6 | ~2 h |
| Jul 9–16 | **2.4 h ± 1.0** |

Driver has been pinned at 570.211.01 since March; crashes got 2× worse anyway. Deterministic software bugs don't trend; aging hardware does. Combined with: instant no-trace reset (= platform-level reset: PSU power-good drop or VRM fault), tight thermal-accumulation-shaped time-to-failure, immunity under memtest's constant high load, and susceptibility whenever the platform is in deep idle (which is ~always, even "active" desktop use draws maybe 50–80 W at the wall with C10 at 97%) — the picture is a component in the power path that misbehaves at **low load**, worsening over months.

This also reframes old evidence:
- **memtest86+ 10 h clean (March)**: memtest pins the CPU — no C-states, constant ~100–150 W draw. If the fault only manifests at low load (many semi-passive PSUs also run 0 RPM below ~30% load and heat-soak), memtest would never crash. The report's central paradox ("crashes only under Linux+NVIDIA") dissolves: it's not Linux+NVIDIA, it's *low power draw*, which only Linux idle achieves.
- **Jan 29 driver-upgrade onset**: plausibly coincidence with degradation crossing threshold — or 580.126 lowered idle draw slightly and tipped a marginal PSU over the edge. Either way the driver was never the cause (both 570 and 580 crash; 595 reports online are a different population).
- **Worsening through spring→summer** is consistent with rising ambient temperature shortening a thermal trip time.

**Discriminating tests (all non-destructive, each conclusive within ~a day).** With MTTF 2.4 h ± 1.0, surviving 12 h under a test is already decisive (>5σ from the current distribution); 24 h is conclusive.

1. **Disable deep C-states at runtime** — no reboot, self-reverting on reboot, instantly reversible:
   ```sh
   # disable C8 + C10 on all cores (C1E/C6 remain available)
   for c in /sys/devices/system/cpu/cpu*/cpuidle/state3/disable /sys/devices/system/cpu/cpu*/cpuidle/state4/disable; do
     echo 1 | sudo tee $c > /dev/null
   done
   # verify: grep . /sys/devices/system/cpu/cpu0/cpuidle/state*/disable
   # revert: same loop with echo 0 (or just reboot)
   ```
   Survives 24 h → trigger is deep package idle (raises wall draw ~10–20 W and keeps VRM/PSU switching in a happier regime). Make persistent with `intel_idle.max_cstate=2` in GRUB while deciding on hardware.
2. **PSU fan check** — zero risk, physical: note the PSU model; if it has a hybrid/Zero-RPM switch, set the fan to always-on (or point a desk fan at the PSU intake). Survives → PSU heat-soak at low load confirmed → replace PSU.
3. **Constant light CPU load** (`stress-ng --cpu 4` or similar) if #1 fails — separates "load keeps it alive" from C-states specifically.
4. **Re-run memtest86+ now** — the March pass is 4 months stale; failure rate has doubled since. If memtest *now* crashes → hardware confirmed outright.
5. **iGPU-only boot** (blacklist nvidia, monitor on motherboard output — the 12700K has UHD 770) if the above are ambiguous — fully exonerates or implicates the NVIDIA stack in one day.

**Likely eventual fix if theory holds: replace the PSU.** Ordinary component swap, not a risky operation. BIOS flash drops to "someday, for hygiene" — no longer load-bearing.

### Plan for today (2026-07-16)

One variable at a time. With MTTF 2.4 h, ~12 h of survival is decisive.

1. **Now:** disable C8/C10 via sysfs (test #1 above). No reboot needed. Note the time. Use the machine normally.
2. **Now (observation only, changes nothing):** identify the PSU — model, wattage, age — and check whether its fan is spinning while the system idles. Note if it has a Zero-RPM/hybrid switch. Don't flip it yet.
3. **Tonight:** if the machine survived >12 h → deep-idle trigger confirmed; add `intel_idle.max_cstate=2` to GRUB as a persistent workaround and plan a PSU swap at leisure.
4. **If it crashed anyway:** C-states exonerated; next test is the PSU fan (flip switch / desk fan) tomorrow, then fresh memtest overnight.

### Test 3: Deep C-states disabled at runtime (2026-07-16) — FAILED

**Result (checked 2026-07-17 08:16):** crashed at **23:05:46**, 2 h 09 m after C8/C10 were disabled (3 h 05 m boot total) — squarely inside the normal 2.4 h ± 1.0 distribution. Five more crashes overnight at the usual cadence (23:07→00:42, 00:43→02:25, 02:27→04:28, 04:29→06:13, 06:14→07:33). No improvement signal whatsoever.

**Conclusion: deep package C-states (C8/C10) are exonerated.** The fault trips even with the CPU capped at C6. Combined with earlier results, the "low-load" condition that matters is not CPU package idle depth. → **Branch B of the playbook is now active.** Next: B2 (PSU fan test — physical), B3 (fresh memtest overnight), B4 (iGPU-only boot).

Original test plan follows for the record:

- **Started: 2026-07-16 20:56:44 PDT** (56 min into the current boot, which began 20:00:21).
- C8 (state3) and C10 (state4) disabled via sysfs on all 20 threads — verified 40/40 `disable` flags set, and cpu0's C10 residency counter fully stopped advancing afterward. Deepest reachable state is now C6.
- **Nothing was made persistent.** No reboot needed; do NOT reboot — the setting lives only in this boot. Any reboot (or crash) silently reverts it to stock behavior.

**What to expect:**
- Under the status quo (last 76 boots: mean uptime 2.41 h, stdev 0.96, max 6.2), this boot should die around **22:25 PDT ± 1 h**.
- Surviving past **~02:00 (6 h uptime)** already beats every one of the last 76 boots.
- Surviving past **~09:00 Thu morning (13 h uptime)** is decisive: deep package idle (C8/C10) is the trigger. Then: add `intel_idle.max_cstate=2` to `GRUB_CMDLINE_LINUX_DEFAULT` + `update-grub` for persistence, and plan a PSU replacement (root cause is still likely marginal power delivery at low load — the C-state cap just keeps draw above the misbehavior threshold, at a cost of ~10–20 W idle).
- **If it crashes anyway** (uptime in the usual 1–4 h band): C-states are exonerated; the fault trips even at C6-max draw. Next: PSU fan test (Zero-RPM switch / desk fan), then fresh overnight memtest — if memtest *now* fails too, hardware is confirmed outright.

**How to check (morning of 07-17):** `last -x reboot | head -3` — if the top entry still shows the `Jul 16 20:00` boot, the test survived. Record the result here either way.

Mid-test sanity check (should show `1` for states 3+4; if a crash happened, these read `0` again):
```sh
grep . /sys/devices/system/cpu/cpu0/cpuidle/state[34]/disable
```

### Debugging playbook — next steps (written 2026-07-16, execute from here)

Decision tree from Test 3's outcome. Every step is non-destructive unless marked. After each step, append the result to the Log table with date/time.

---

**BRANCH A — Test 3 SURVIVED (>13 h uptime): deep-idle trigger confirmed.**

A1. Record result (uptime achieved, what the machine was doing). Then make the C-state cap persistent:
```sh
# edit /etc/default/grub: append intel_idle.max_cstate=2 to GRUB_CMDLINE_LINUX_DEFAULT
sudo sed -i.bak 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 intel_idle.max_cstate=2"/' /etc/default/grub
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub   # eyeball it
sudo update-grub
sudo reboot
# verify after reboot: deepest listed state should be C6, and param present:
cat /proc/cmdline
grep . /sys/devices/system/cpu/cpu0/cpuidle/state*/name
```
Revert: restore `/etc/default/grub.bak`, `sudo update-grub`, reboot.

A2. Monitor 3–7 days (`last -x reboot`). Stable → workaround confirmed; the machine is usable again. Idle power cost ~10–20 W.

A3. Optional refinement (narrows which state is toxic, recovers some power): re-enable C8 but keep C10 off — at runtime, `echo 0` to state3/disable only (keep state4 disabled... note: with `max_cstate=2` in GRUB, states 3/4 don't exist; to test this, remove the GRUB param and use a boot-time systemd unit or /etc/rc.local-style sysfs writes instead). Only bother if the idle power cost matters.

A4. Root cause is still likely marginal power delivery at low load (PSU first, board VRM second). The cap is a shim, and the degradation trend (24 d → 2.4 h over 6 months) says the component will keep aging — possibly until the cap stops being enough. **Recommend PSU replacement soon anyway.** Any quality 750 W+ ATX unit works for a 12700K + RTX 3090. Before buying, note the current PSU's model/age (A5).

A5. Identify current PSU (physical look, or side panel off): brand, model, wattage, manufacture date, whether it has a Zero-RPM/hybrid switch, whether the fan spins at idle. Record here.

---

**BRANCH B — Test 3 FAILED (crashed with C8/C10 disabled): C-states exonerated.**

Order: B1 (free, observational) → B2 (physical, zero risk) → B3 (free, overnight) → B4 (software, reversible) → B5 (hardware swap).

B1. Record the crash time + uptime in the Log. Confirm the setting was actually active before the crash if possible (it was verified at 20:56 on 07-16; flags reset to 0 after reboot is expected and does NOT mean the test was invalid).

B2. **PSU fan test.** Physically inspect PSU. If it has a Zero-RPM/hybrid/eco switch: set fan to always-on. If not: point a desk fan directly at the PSU intake. One variable — change nothing else. Watch 24 h (`last -x reboot`). Survives → PSU heat-soak at low load confirmed → replace PSU (B5).

B3. **Fresh memtest86+ overnight** (March's pass is stale; failure rate has doubled since). Boot memtest from GRUB menu or USB, run 8+ h. Machine resets/crashes during memtest → hardware confirmed outright (PSU/board/CPU — GPU driver fully exonerated); go to B5. Passes → the fault needs the OS's low-power operation; proceed B4.

B4. **iGPU-only boot** (removes the entire NVIDIA stack; 12700K has UHD 770):
```sh
printf 'blacklist nvidia\nblacklist nvidia_drm\nblacklist nvidia_modeset\nblacklist nvidia_uvm\n' \
  | sudo tee /etc/modprobe.d/blacklist-nvidia.conf
sudo update-initramfs -u
# move monitor cable to the motherboard's HDMI/DP output, then:
sudo reboot
# verify: lsmod | grep nvidia  -> empty; glxinfo | grep -i renderer -> Intel/Mesa
```
If no display on the motherboard output, iGPU may be disabled in BIOS setup (settings toggle only — NOT a flash): Advanced → System Agent → Graphics Configuration → iGPU Multi-Monitor = Enabled.
Revert: `sudo rm /etc/modprobe.d/blacklist-nvidia.conf && sudo update-initramfs -u && sudo reboot`.
- Survives 24 h → NVIDIA stack implicated after all (driver's power management keeping the GPU in P8 low-draw is part of the low-load condition; or kmod bug). Combined with B2/B3 results, decide between PSU swap and deeper driver work.
- Crashes anyway → hardware near-certain even with GPU stack absent → B5.

B5. **Hardware, in order of likelihood/cost:**
   1. Replace PSU (most likely; ordinary swap).
   2. Reseat GPU + both ends of all PCIe power cables; try different modular cables if available.
   3. Try GPU in the second PCIe slot (x8 via chipset — fine for testing).
   4. If a new PSU doesn't fix it: board VRM/board itself is the remaining suspect; BIOS flash 1720→4505 (Procedure C above) becomes worth doing before condemning the board.

---

**Standing notes for whoever executes this (including future Claude):**
- MTTF is ~2.4 h ± 1.0 (n=76, Jul 2026), so any single change that yields >12 h uptime is decisive (>5σ); >24 h is conclusive. No need for multi-day waits per test.
- One variable at a time. Every test above is independently revertible.
- Check `last -x reboot | head` first thing in any session to see what happened since.
- The sysfs C-state disable does NOT persist — after any reboot the machine is back to stock deep-idle behavior unless the GRUB param from A1 was applied.
- Do not bother with: BIOS ASPM toggles (ASPM confirmed off at every level, 06-06), newer NVIDIA drivers (595 crashes identically per online reports, 06-06), kernel upgrades (five kernels made no difference).

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
| ~2026-04 | Kernel auto-upgraded 6.8.0-106 → 6.8.0-110 via unattended-upgrades. No help. |
| 2026-04-21 to 04-25 | **25 unclean reboots in 5 days**, avg ~3.7 hr uptime. Pattern unchanged from March. No clean shutdowns. PEG1.PEGP `_DSM.USRG` ACPI error still firing at every boot. No log trace before any crash. |
| 2026-04-25 | Status check appended to report. No physical/firmware changes made yet. BIOS still 1720, kernel params unchanged, driver 570.211.01. Stale nvidia-firmware-580 packages still installed. Recommended next step: disable ASPM in BIOS UI (free, reversible) before considering BIOS flash. |
| ~2026-05 | Kernel auto-upgraded 6.8.0-110 → 6.8.0-124 via unattended-upgrades. No help. |
| 2026-06-05/06 | **~15 hard resets over 2 days**, avg uptime ~1.5–2.5 hr — worse than April. Zero clean shutdowns since wtmp begins (May 17). |
| 2026-06-06 | **ASPM conclusively ruled out via live `lspci -vv`.** GPU endpoint `ASPM Disabled` + all L1 substates off; upstream root port `00:01.0` reports `ASPM not supported`. `pcie_aspm=off` was honored all along — ASPM never mattered. Kills the 03-21→04-25 ASPM theory. `_DSM` ACPI error still fires this boot. GPU `runtime_status=active`, `power/control=auto`. **Revised: BIOS flash 1720→4505 now #1 lever** (only fix for broken `_DSM`); BIOS ASPM toggle dropped as redundant. Online: no public fix; driver 595 (May 2026) still crashes identically — newer driver not the answer. |
| 2026-07-16 | **Theory revised: low-load power-delivery failure (PSU prime suspect).** Live analysis: 76 recent boots show metronomic crashes (mean 2.41 h ± 0.96) at all hours incl. active use — idle correlation gone. Journal written <5 s before every reset. Zero Xid/MCE/AER in 483 reboots; no watchdog armed. GPU runtime PM never engages (`runtime_suspended_time=0`) → broken `_DSM` never exercised at runtime → BIOS-flash-as-#1-lever demoted. C10 residency ~97% even during active use → memtest immunity (constant high load, no C-states) no longer contradicts hardware. Monotonic degradation on frozen software (24 d → 2.4 h over 6 months) points to aging hardware in the power path. Next: runtime C-state disable test, PSU fan check, fresh memtest. |
| 2026-07-16 20:56 | **Test 3 started: C8/C10 disabled at runtime via sysfs** (all 20 threads, verified; C10 residency stopped advancing). Not persistent — reverts on any reboot/crash. Expected crash under status quo ~22:25 ± 1 h; surviving past ~09:00 on 07-17 (13 h) = deep-idle trigger confirmed → make persistent with `intel_idle.max_cstate=2` and plan PSU swap. Crash anyway = C-states exonerated → PSU fan test, then fresh memtest. |
| 2026-07-16 23:05 | **Test 3 FAILED.** Crashed 2 h 09 m after C-states were capped at C6 — inside the normal distribution. Five more crashes overnight (00:42, 02:25, 04:28, 06:13, 07:33), cadence unchanged. **C8/C10 exonerated.** Playbook Branch B active: next is B2 (PSU fan, physical), B3 (fresh memtest), B4 (iGPU-only boot). |

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

### Current status (2026-04-25)

**Same problem, four weeks later.** No physical/firmware changes were attempted. Kernel auto-upgraded from -106 to -110 via unattended-upgrades; that did nothing.

- 25 silent hard resets in the last 5 days. Avg uptime ~3.7 hrs.
- Last clean shutdown: 2026-03-28.
- ACPI `_DSM.USRG` error on PEG1.PEGP still fires at every boot.
- Out of software-side moves. The remaining levers are all firmware/physical (BIOS ASPM toggle, BIOS flash 1720→4505, nouveau diagnostic, GPU reseat/slot swap).

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
