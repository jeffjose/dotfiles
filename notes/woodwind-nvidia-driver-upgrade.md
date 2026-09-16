# Woodwind NVIDIA Driver Upgrade: 570 → 610 (2026-09-15)

Change record + rollback for lifting the March 2026 driver pin.
Companion to [woodwind-nvidia-crash-report.md](woodwind-nvidia-crash-report.md).
Script: [`scripts/utils/upgrade-nvidia-woodwind.sh`](../scripts/utils/upgrade-nvidia-woodwind.sh)

---

## Why

**Trigger:** ComfyUI Desktop refused to start:

```
RuntimeError: The NVIDIA driver on your system is too old (found version 12080).
```

The error is accurate, not a misdetection:

| | |
|---|---|
| Driver installed | `570.211.01` → exposes CUDA **12.8** (= `12080`) |
| What ComfyUI ships | `torch==2.12.1+cu130` → needs CUDA **13.0** |
| Requirement | CUDA 13 is a *major* bump → driver **≥ 580.65** |

CUDA minor-version compatibility only works *within* 12.x, so 570 cannot run a
cu130 wheel under any configuration. Source of the pin:
`~/ComfyUI-Installs/ComfyUI/requirements-nvidia.txt` (and `manifest.json`,
`torch_version: 2.12.1+cu130`) — deliberately version-pinned by the vendor, so
patching torch down to cu128 would be reverted on the next desktop-app update.

**Why it was safe to unpin:** the 570 pin dates to 2026-03-21, set while chasing
silent hard resets. That investigation closed on **2026-07-18**: root cause was
the **Seasonic PRIME 1200W PSU heat-soaking at idle** with its semi-passive fan
stopped. Test 4 (2026-07-17) crashed with the NVIDIA stack *fully removed*,
conclusively exonerating the driver. The pin was guarding a dead theory.

Corroborating evidence at upgrade time: **10 days uptime** (boot 2026-09-05),
against the 2.41 h ± 0.96 MTTF that triggered the pin. Fix is holding.

> ⚠️ **The actual fix is the PSU Hybrid Mode button being OFF (out/up).**
> Nothing here touches it. Do not press it back in.

---

## What changed

| # | Change | Backup / revert |
|---|---|---|
| 1 | Deleted `/etc/apt/preferences.d/nvidia-pin` (pinned `nvidia-driver-*` to `570.*` at priority 1001) | `/root/nvidia-pin.bak.<stamp>` |
| 2 | Stripped 3 crash-era params from `/etc/default/grub` | `/root/grub.bak.<stamp>` |
| 3 | `nvidia-driver-570` (570.211.01) → `nvidia-driver-610` (610.57.04) | `apt install nvidia-driver-570` |
| 4 | Purged 2 orphaned `nvidia-firmware-580-*` + 9 `rc` config residues | none needed (orphans) |

### Kernel params removed in step 2

All three were failed workarounds for theories the crash report closed:

```
pcie_aspm=off                             # ASPM ruled out 2026-06-06
nvidia.NVreg_EnableGpuFirmware=0          # GSP disable — unsupported on modern
                                          #   drivers; must NOT ride onto 610
nvidia.NVreg_DynamicPowerManagement=0x00  # GPU power-mgmt workaround
```

`NVreg_EnableGpuFirmware=0` was the one that actually mattered to remove: GSP
firmware is expected on 580+, and carrying a stale disable flag onto a new
driver is a real risk of a broken X session.

### Driver version chosen

`610.57.04` — newest in jammy-updates/multiverse. Alternatives that also clear
the CUDA 13 bar: `595.91.07` (what `ubuntu-drivers devices` recommends,
`-open`), `590.48.01`, `580.178.04` (bare minimum). Stayed on the **proprietary**
(non-`-open`) variant to match the previous setup and hold variables steady.

Pre-flight `apt-get install -s` resolved clean: 23 installs, 20 removals, no
unmet dependencies. Secure Boot is disabled → no MOK enrollment step. Headers
present for the running kernel, so DKMS builds without extra setup.

---

## Rollback

Full revert to the pre-upgrade state:

```sh
STAMP=<pick from /root/*.bak.*>

# 1. driver back to 570
sudo apt install -y nvidia-driver-570

# 2. restore crash-era GRUB params
sudo cp /root/grub.bak.$STAMP /etc/default/grub
sudo update-grub

# 3. re-pin (only if you actually want 570 held)
sudo cp /root/nvidia-pin.bak.$STAMP /etc/apt/preferences.d/nvidia-pin

sudo reboot
```

Note that rolling back re-breaks ComfyUI — 570 cannot run the cu130 torch.

---

## Verification after reboot — DONE 2026-09-15 22:08, all green

| Check | Result |
|---|---|
| `nvidia-smi` | `610.57.04`, CUDA UMD **13.3**, RTX 3090 detected, P8 / 31 W / 41 °C |
| `cat /proc/cmdline` | `ro quiet splash vt.handoff=7` — all 3 crash-era params gone |
| `dkms status` | `nvidia/610.57.04, 6.8.0-138-generic: installed` |
| Driver packages | `nvidia-driver-610 610.57.04-0ubuntu0.22.04.3`; all 22 nvidia pkgs on -610 |
| 580 remnants | none |
| Xid errors | **0** |
| X11 session | healthy (Xorg on vt7 via lightdm) |

**ComfyUI torch now initializes.** Note the venv is `ComfyUI/ComfyUI/.venv` —
*not* `standalone-env`, which has no torch in it:

```
torch          : 2.12.1+cu130
torch cuda ver : 13.0
cuda available : True
device         : NVIDIA GeForce RTX 3090   capability (8, 6)
matmul on GPU  : OK
```

Original `RuntimeError: ... driver is too old (found version 12080)` is resolved.

**Watch for:** crashes returning would be surprising and would *not* implicate
610 by default — check the PSU Hybrid Mode button first.

---

## Gotcha hit during the upgrade: nvidia-persistenced user deleted

After the reboot, one unit had failed:

```
nvidia-persistenced.service: Failed with result 'exit-code'
ERROR: Failed to find user ID of user 'nvidia-persistenced': Success
```

**Cause — a dpkg ordering hazard.** `nvidia-compute-utils-610.postinst` creates
the `nvidia-persistenced` system user; `nvidia-compute-utils-570.postrm` runs
`userdel nvidia-persistenced`. dpkg configured 610 *before* removing 570, so the
old package's postrm deleted the user out from under the new one. Both the user
and its group ended up missing while `nvidia-compute-utils-610` sat happily at
`ii`.

Impact was cosmetic — GPU, CUDA and ComfyUI all worked without it (the daemon
runs with `--no-persistence-mode` and only avoids driver re-init latency) — but
it left a permanently failed unit.

**Fix, now folded into the script as step 5 (idempotent — just re-run it):**

```sh
sudo dpkg-reconfigure nvidia-compute-utils-610
sudo systemctl restart nvidia-persistenced
```

Two other script fixes came out of this run:

- **Step 4 is now version-agnostic.** It only swept `-580` before, so the 4 `rc`
  residues the 570 *removal itself* creates (`libnvidia-compute-570`,
  `nvidia-compute-utils-570`, `nvidia-dkms-570`, `nvidia-kernel-common-570`)
  survived it. It now sweeps every series except `$TARGET`.
- **The series regex is anchored** as `-(4|5|6)[0-9][0-9](-|$)`. A looser
  `-[0-9][0-9][0-9]` also matched `linux-signatures-nvidia-6.8.0-138-generic`
  via the *kernel* version, which must never be purged.

---

## Log

| Date | Event |
|------|-------|
| 2026-03-21 | Downgraded 580.126.09 → 570.211.01, apt pin set, via `~/scripts/fix-nvidia.sh` (untracked). Driver suspected; wrong. |
| 2026-07-18 | Root cause confirmed: PSU semi-passive fan heat-soak. Hybrid Mode OFF = fix. Driver exonerated. |
| 2026-09-05 | Current boot begins. |
| 2026-09-15 | ComfyUI install hits the `12080` error. Pin traced, confirmed obsolete. Upgrade scripted to 610.57.04 and recorded here. Superseded `~/scripts/fix-nvidia.sh`. |
| 2026-09-15 22:06 | Script run; rebooted onto **610.57.04 / CUDA 13.3**. All checks green, 0 Xid, ComfyUI torch cu130 initializes on the GPU. Two follow-ups: `nvidia-persistenced` user deleted by the 570 postrm (fixed, script step 5), and 4 stale 570 `rc` residues left by a too-narrow sweep (fixed, step 4). |
