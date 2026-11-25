# m51-hyperos — HyperOS + everything for the Samsung Galaxy M51 (SM-M515F)

Everything for the Galaxy M51 on **one page**: the phone, how to unlock
it, how to flash TWRP, how to root it, how to flash the stock ROM, how
to flash HyperOS (GSI), how to flash UN1CA, how to flash the custom
kernel, how to log what happened, and the honest status of every part
of this project.

> **Honest status, up front.** HyperOS has **not** booted on an m51 in
> front of us yet, and no UN1CA build of ours has been flashed and
> tested yet either. What *is* proven: the device trees exist and are
> pinned, the custom kernel builds green, the spring GSI is verified
> and mirrored, the stock firmware is downloaded and verified, the
> lights and fingerprint work is reverse-engineered, and the logger
> and live watcher are built and tested. The rest is work in progress
> with the evidence named next to each claim — nothing here is
> presented as working until it has actually run on the phone.
>
> **Do the DSU trial first.** A GSI that does not boot as a trial will
> not boot flashed either — and flashing wipes your data. The trial
> costs nothing; the flash costs a backup.

## Contents

1. [The phone — Galaxy M51 at a glance](#1-the-phone--galaxy-m51-at-a-glance)
2. [Before you flash anything](#2-before-you-flash-anything)
3. [Unlock the bootloader](#3-unlock-the-bootloader)
4. [Flash TWRP](#4-flash-twrp)
5. [Root with Magisk](#5-root-with-magisk)
6. [Flash the stock ROM](#6-flash-the-stock-rom)
7. [Flash HyperOS (GSI)](#7-flash-hyperos-gsi)
8. [Flash UN1CA](#8-flash-un1ca)
9. [Flash the custom kernel](#9-flash-the-custom-kernel)
10. [Logging — capture what happened](#10-logging--capture-what-happened)
11. [Project status — everything, honestly](#11-project-status--everything-honestly)
12. [Known issues](#12-known-issues)
13. [Repo layout](#13-repo-layout)
14. [Per-device procedures](#14-per-device-procedures)
15. [Troubleshooting](#15-troubleshooting)
16. [Credits](#16-credits) · [License](#license)

## 1. The phone — Galaxy M51 at a glance

| Fact | Value |
|---|---|
| Model | **SM-M515F** (Galaxy M51, international). No other model is covered anywhere in this repo. |
| SoC | Qualcomm Snapdragon 730G (**SM7150**, `sm6150` platform) |
| RAM / storage | 6 GB / 128 GB |
| Battery | 7,000 mAh |
| Display | 6.7" Super AMOLED Plus, **60 Hz** (the panel reports only 60 Hz modes — nothing renders at 120 on this phone) |
| Fingerprint | Side-mounted, at `1080\|800\|350` |
| Stock OS | Android 12 / One UI 4.1, build `SP1A.210812.016.M515FXXU6DXJ1`, patch 2024-05-01 |
| Stock firmware (latest, INS) | PDA `M515FXXU6DXJ1`, CSC `M515FODM6DXJ1`, modem `M515FXXU6DXJ1`, bootloader **6** |
| Kernel | Linux 4.14 (stock; our custom build is 4.14.357-openela) |
| Vendor | Frozen at Android 12 — VNDK 31, FCM target-level 6, 913 proprietary blobs |
| Partitions | Dynamic partitions (super: system, vendor, product, system_ext, odm) |
| Recovery | Unofficial TWRP 3.7.0_11-0 (verified — see §4) |
| Bootloader | Unlocked on our phone. Knox tripped permanently, Widevine L3. |

## 2. Before you flash anything

Read this section once, whatever you are about to flash. Every
procedure below assumes it.

1. **Back up everything.** Photos, files, app data — copy them off
   the phone and check you can open the copies. Unlocking wipes the
   phone. A stock flash with the CSC file wipes the phone. A GSI or
   UN1CA flash needs a Format Data. Assume a wipe.
2. **Back up EFS first (TWRP users).** In TWRP, back up the EFS
   partition and keep a copy off the phone. EFS holds the IMEI and
   modem calibration — losing it is very hard to recover from.
3. **Log out of Google and Samsung accounts** before unlocking or
   wiping, or Factory Reset Protection can lock you out of your own
   phone afterwards.
4. **Battery above 50%, ideally full.** A dead phone mid-flash is
   how bricks happen. Use a good USB data cable (charge-only cables
   will not work) and a USB port on the PC itself — no hubs, no
   front-panel ports.
5. **Check the phone first.** Settings → About phone → Software
   information: model must read **SM-M515F** and the service
   provider software version must show **INS**. Do not flash
   anything in this repo on any other model or region.
6. **Know what unlocking costs.** Unlocking the bootloader wipes the
   phone once, trips Knox **permanently** (Samsung Pay / Secure
   Folder never come back), drops Widevine to L3 (no HD Netflix),
   and can break banking apps (Play Integrity). Flashing stock
   firmware does **not** untrip Knox.
7. **Never relock the bootloader** with TWRP, Magisk, or any custom
   image installed — that bricks the phone. Never write to the
   bootloader partitions (`aboot` / `xbl` / `sbl`) from root — same
   result.
8. **The one rule that matters most: never let anything overwrite
   the recovery partition.** Our phone runs TWRP, and every zip,
   image and procedure in this project is checked against that rule:
   UN1CA, GSI, kernel and stock flashes must all leave recovery
   untouched (or re-flash TWRP immediately, before the first boot
   into system — see §4 and §6). Check every tar you flash for a
   `recovery.img` entry first.
9. **Have a way back before you start.** A full stock-firmware
   backup and a working Odin restore path (§6) is your way back from
   anything below except a broken bootloader.

## 3. Unlock the bootloader

You only do this once. It wipes the phone.

1. Do everything in §2 first — backup, EFS, log out of accounts.
2. Enable Developer options (Settings → About phone → tap Build
   number 7 times), then turn on **OEM unlocking** and **USB
   debugging**.
3. Power the phone fully off. Press and hold **Volume Up + Volume
   Down**, then connect the USB cable to the PC. A warning screen
   appears — press **Volume Up** to continue into Download mode.
4. In Download mode, long-press **Volume Up** to unlock the
   bootloader. Confirm on screen. The phone wipes itself and
   reboots.
5. Set the phone up minimally (or skip setup) — you only need adb
   working for the next steps.
6. Check: Settings → Developer options → **OEM unlocking** should
   now show as unlocked / greyed out. `adb reboot bootloader` then
   `fastboot oem device-info` is not available on Samsung — the
   Download mode screen itself shows the lock state.

> If OEM unlocking is greyed out or missing, the phone is likely
> carrier-locked or the 7-day waiting period applies (Samsung
> enforces a wait after first setup on some firmwares). Wait it out;
> there is no supported bypass.

## 4. Flash TWRP

**What TWRP is:** a custom recovery — the menu you boot into to
install zips, make backups, and wipe. Everything in this repo is
flashed through it. Our phone runs it; every procedure below
assumes it.

**Verified build:** TWRP **3.7.0_11-0** for m51, built 2025-06-05,
Android 11 base, kernel Linux 4.14.190+. The image on our phone was
checked file-by-file against the reference build and is identical
(version, fingerprint `samsung/twrp_m51/m51:11/RQ1A.210205.004/
runner06050938`, build date, build host). Full check:
[docs/twrp-user-check.md](docs/twrp-user-check.md).

**What you need**

- Unlocked bootloader (§3).
- A Windows PC with the **Samsung USB Driver** installed (from
  Samsung: developer.samsung.com) and Samsung Smart Switch closed.
- **Odin3 v3.14.1** — see §6 for the download and the SHA-256 check.
  (Odin is Windows-only; Linux: `samloader-rs flash`.)
- `vbmeta_disabled.tar` — a disabled vbmeta, so the unsigned TWRP
  and GSI can boot. Named in the XDA TWRP thread below.
- The **TWRP tar** for m51 — XDA thread "[RECOVERY][UNOFFICIAL]
  TWRP for Galaxy M51 (Snapdragon)":
  <https://xdaforums.com/t/recovery-unofficial-twrp-for-galaxy-m51-snapdragon.4559657/>
- `multidisabler` — named in the same thread; stops stock from
  re-encrypting / re-locking things after the flash.
- Battery above 50%, a good data cable, a USB port on the PC.

**Steps**

1. Boot into Download mode (power off, hold **Volume Up + Volume
   Down**, connect USB, press **Volume Up** at the warning).
2. Open Odin **as administrator**. The `ID:COM` box turns blue and
   shows `Added!` when the phone is detected. If nothing appears,
   the driver/cable/port is the problem — do not proceed.
3. Load `vbmeta_disabled.tar` in Odin and flash it (AP slot, as in
   the XDA thread). Wait for PASS.
4. Load the **TWRP tar in the AP slot** and flash it. Wait for PASS.
   > Do **not** follow the vbmeta-on-USERDATA variant that appears
   > in some other guides (it puts a vbmeta image on the userdata
   > partition, which is unusual and unverified). The XDA-thread
   > route above is the one our docs use.
5. **The moment Odin shows PASS, boot straight into recovery — do
   not let the phone boot to system.** Hold **Volume Up + Power**
   until the TWRP logo appears. If the phone boots to system first,
   stock recovery gets restored and you have to flash TWRP again.
6. In TWRP, run **`multidisabler`** (Install → select the zip →
   flash).
7. **Format Data:** Wipe → Format Data → type `YES`. (This is a
   format, not a wipe — it removes encryption so TWRP and the ROM
   can use /data.)
8. Reboot → System for a stock boot, or stay in TWRP for the next
   flash (§5–§9).

**Check it worked:** reboot to recovery (power off, hold Volume Up +
Power) — TWRP 3.7.0_11-0 opens. In TWRP, the version is shown on
the main screen.

**Keeping TWRP — the rules**

- A full stock AP flash **replaces TWRP** with stock recovery
  (the stock AP tar contains `recovery.img`). To keep TWRP, either
  remove `recovery.img` from the AP tar before flashing (advanced —
  re-pack the tar and recompute the trailing MD5), or flash stock
  and then **immediately re-flash TWRP before the first boot into
  system** (§6).
- Never let a ROM's own updater touch recovery: do not check any
  "update recovery on first boot" box — on this device that flow is
  broken and will cost you a re-flash through Odin.
- After any stock flash, re-flash TWRP before doing custom work
  again — and take a fresh TWRP backup (including EFS) once the
  phone is back on stock.
- /data decryption inside TWRP (FBE) is present in code but
  **unproven on the device** — test a /data backup before relying
  on it; keep your real backups on the system side.

**If it goes wrong:** Odin does not see the phone → reinstall the
Samsung USB Driver, try another port/cable, confirm Download mode.
TWRP is gone after a boot → you booted to system first; re-flash
from step 2. Stuck on the Samsung logo after flashing → boot into
recovery and Format Data again.

## 5. Root with Magisk

**What root is:** administrator access to the phone's own system —
you can read and change anything, install modules, run root apps
(and our logger's root-only collectors). Our phone is already
rooted; this section documents the exact methods so anyone can
reproduce it.

**What root costs:** Knox is already tripped by the unlock, so root
adds no new permanent loss — but banking apps and Play Integrity
can fail on a rooted phone, system OTA updates will remove root (do
not take them), and you must **never relock the bootloader** with
root installed. To unroot: flash the stock boot/AP (§6), or Magisk
→ Uninstall → Restore Images, then flash stock boot.

Three methods work on the m51. Magisk is the standard one; the
other two are listed because other m51 repos recommend them — with
the warnings attached.

### Method A — Magisk, patch the AP (Samsung standard, no TWRP needed)

1. Download the **Magisk APK** (latest release) from
   <https://github.com/topjohnwu/Magisk/releases> and install it
   on the phone.
2. Copy the stock **AP tar** (`AP_M515FXXU6DXJ1_...tar.md5`, from
   the §6 firmware) to the phone's internal storage.
3. Open Magisk → **Install** → **Select and Patch a File** → pick
   the AP tar. Magisk patches it (takes minutes — the AP is huge)
   and writes `magisk_patched-*.tar` to the Download folder.
4. Copy the patched tar back to the PC.
5. Boot into Download mode (§3 step 3), open Odin as administrator.
6. Load the **patched tar in the AP slot**. If the phone is already
   on this exact stock build, AP-only is enough; otherwise load
   BL / CP / CSC from the same §6 package as well. Leave
   Re-Partition unticked. Click Start, wait for PASS.
7. Reboot. Open Magisk — it shows **Installed**. Verify from a PC:
   `adb shell su -c id` → `uid=0(root)`.

### Method B — Magisk, patch the boot image (needs TWRP)

1. Extract `boot.img` from the stock AP tar (the AP tar is a plain
   tar — `tar -xf AP_...tar.md5 boot.img`).
2. Copy `boot.img` to the phone. In the Magisk app: Install →
   Select and Patch a File → pick `boot.img` → you get
   `magisk_patched-*.img` in Download.
3. Copy the patched image back to the phone. In TWRP: Install →
   **Install Image** → select the patched image → flash to the
   **Boot** partition. Reboot.
4. Verify as in Method A.

### Method C — Magisk zip in TWRP

1. Rename the Magisk APK to `Magisk-vXX.zip` and copy it to the
   phone (or an SD card).
2. In TWRP: Install → select the zip → flash → reboot.
3. Verify as in Method A. (The Magisk app can also do a Direct
   Install once the phone is already booted with a patched boot.)

### Other root methods (from other m51 repos — read before using)

- **APatch — recommended by myghi63** (the LineageOS/crDroid
  builder for the m51). Same shape as Method B: extract `boot.img`
  from the stock AP, patch it in the APatch app (KernelPatch-based),
  flash the patched boot image in TWRP to the Boot partition,
  reboot. The APatch app then shows the patch as working. We have
  not run APatch end-to-end on this phone ourselves — myghi63 lists
  it as his recommended method; Magisk above is the one with the
  full step-by-step verified against Samsung practice.
- **KernelSU — not recommended.** KernelSU needs a kernel built
  with KernelSU support. Our crDroid kernel does not have it, and
  the kernel myghi63 pairs it with (AniK Kernel) is not linked or
  described anywhere we could verify. Do not chase KernelSU on this
  phone unless you build or obtain a KernelSU-enabled kernel for
  the m51 first.
- **AAO (Automatic Android Optimizer) — do not install.** It is a
  nightly Magisk optimizer that fights our lag fix: it re-tunes
  zram and swappiness away from the values our fix pack sets
  (§8). It will undo the fix on every boot.

**After root:** modules install from the Magisk app (or APatch
app). If a banking app fails, that is Play Integrity, not a broken
root — UN1CA ships a Play Integrity Fix (§8); on stock, PIF /
Shamiko-style modules exist but are **not verified by us** on this
phone, so they are named here, not recommended.

## 6. Flash the stock ROM

**When:** return the phone to official Samsung firmware — unbrick,
undo a bad flash, get a known-good base before custom work, fix a
bootloop TWRP cannot fix. Full detail:
[docs/FLASHING-GUIDE.md](docs/FLASHING-GUIDE.md).

**What you are flashing**

| Field | Value |
|---|---|
| Model / region | SM-M515F / **INS (India)**, CSC `M515FODM6DXJ1` |
| PDA / AP | `M515FXXU6DXJ1` |
| Modem / CP | `M515FXXU6DXJ1` |
| Build number | `SP1A.210812.016.M515FXXU6DXJ1` |
| Android / One UI | Android 12 / One UI 4.1, patch 2024-05-01, changelist 23974102 |
| Bootloader | **6** — after this flash, no firmware with bootloader 5 or lower will install (anti-rollback) |
| Server file | `SM-M515F_2_20241004032751_smm7rurrx5_fac.zip` (5,964,436,871 B) |
| MD5 / SHA-256 | `d3afc8d09f0bf94faaeccfd29517c9df` / `0e71ca19c9d2af6eb8b63e9882218792f855d90326893312bdfa4e1ff5ab50c5` |

This is the latest official firmware for INS, downloaded from
Samsung's servers and verified by us (all 5 files present, trailing
MD5s check, zip CRCs clean). **DXJ2 is the same build for Latin
America only** — not newer, not for INS. Get the file from our
Drive mirror `backups/m51-hyperos/firmware/` (too big for GitHub)
and **verify the hashes above before flashing** — do not flash a
file whose hash does not match. Full fetch/verify record:
[docs/FIRMWARE.md](docs/FIRMWARE.md).

**What you need**

- A Windows PC (Odin is Windows-only; Linux: `samloader-rs
  flash`, same Odin protocol — not covered step-by-step here).
- Samsung USB Driver installed, Smart Switch closed.
- **Odin3 v3.14.1** (the conservative choice — 2,595,015 B,
  SHA-256 `638296a11b1bfa954991b0597214d833511b973480ae9e15e299a761fea1f794`,
  from the XDA Odin3 thread or <https://getodintool.com/>).
  Verify with PowerShell:
  `Get-FileHash .\Odin3-v3.14.1.zip -Algorithm SHA256`.
  Odin3 v3.14.4 is **disputed** (same compile date as v3.14.1,
  older DLL, an unsigned DLL no component references, four
  different ZIPs circulating) — we do not recommend it. Odin is a
  leaked internal tool, not officially distributed by Samsung, and
  its binary is **never committed to our repos**. Do not use any
  file claiming to be a newer Odin3 than v3.14.4.
- The firmware zip, extracted to its five `.tar.md5` files (Odin
  verifies each file's trailing MD5 before flashing):

| File | Odin slot | What it is |
|---|---|---|
| `BL_M515FXXU6DXJ1_...tar.md5` | **BL** | Bootloader |
| `AP_M515FXXU6DXJ1_...tar.md5` | **AP** | System (largest; minutes to load) — contains `boot.img`, `recovery.img`, `system.img`, `vendor.img` |
| `CP_M515FXXU6DXJ1_...tar.md5` | **CP** | Modem / baseband |
| `CSC_ODM_M515FODM6DXJ1_...tar.md5` | **CSC** | Region data — **wipes the phone** (factory reset) |
| `HOME_CSC_ODM_M515FODM6DXJ1_...tar.md5` | **CSC** | Same region data — **keeps your apps and data** |

Load all five files from the **same** package. Never mix files from
different builds or regions.

**Steps**

1. Back up (§2) — and EFS via TWRP if you have it.
2. Enter Download mode: power off, hold **Volume Up + Volume
   Down**, connect USB, press **Volume Up** at the warning.
3. Open Odin **as administrator**. `ID:COM` turns blue, `Added!`
   in the log. Nothing appears → driver/cable/port problem; stop.
4. Load the files into their slots: **BL** → BL file, **AP** → AP
   file (wait for the MD5 check to finish), **CP** → CP file,
   **CSC** → CSC *or* HOME_CSC (CSC wipes, HOME_CSC keeps data).
5. Options: leave **Auto Reboot** and **F. Reset Time** ticked.
   Leave **Re-Partition unticked** (ticking it without a PIT file
   will fail or brick). Touch nothing else.
6. Click **Start**. Do not unplug, touch the phone, or close Odin.
   The flash takes several minutes; the phone reboots by itself
   when Odin shows **PASS** in green.
7. First boot can take several minutes. Check Settings → About
   phone → Software information: build number must read
   `SP1A.210812.016.M515FXXU6DXJ1`.

**Keeping TWRP through a stock flash.** The full stock AP
**replaces TWRP** (it contains `recovery.img`). Two ways to keep
it: (1) remove `recovery.img` from the AP tar before flashing
(advanced — re-pack the tar and recompute the trailing MD5; the
`.md5` suffix is only a checksum footer, not a signature); or (2)
flash stock, then **immediately re-flash TWRP before the first boot
into system** (§4 steps 2–5, then boot straight into recovery).
After any stock flash, re-flash TWRP before custom work, and take a
fresh TWRP backup (including EFS).

**Other repos' way back (myghi63's stock-restore variant):** his
guide restores stock with AP/BL/CP/CSC in Odin and **HOME_CSC left
empty, then a data wipe after** — or **AP-only** for a functional
stock restore without touching the other partitions. Same result as
above by a shorter route; the CSC-vs-HOME_CSC choice above is ours.

**If it goes wrong:** Odin shows FAIL → read the exact line where
the log stopped; common causes are wrong model/region firmware, a
corrupted download (re-check the hashes), a bad cable, or a dying
battery. `SW REV CHECK FAIL` → the package's bootloader is older
than the phone's (anti-rollback). Stuck on the logo / bootloop →
boot into recovery, wipe cache, then factory reset; still stuck →
re-flash the full package with the **CSC** file (wipe). No signal /
wrong region features → wrong CSC; re-flash with the INS package.
TWRP is gone after the flash → expected; re-flash it (§4).

## 7. Flash HyperOS (GSI)

HyperOS on the m51 is a **GSI** — a generic system image from the
community (MysticGSI), flashed over the m51's own stock vendor.
There is no device-specific HyperOS port for the m51, and the only
automated HyperOS porter (XMAPort) is Xiaomi→Xiaomi only: it needs
an official HyperOS base ROM for the target, and the m51 has none.
The GSI is the proven route — the sister device A71 boots HyperOS 2
this way, and m51 HyperOS boots via GSI have been reported on
Telegram (unlinked — Telegram groups are not web-indexed, so no
link can be given; the report is user-reported). Full guides:
[docs/dsu-trial.md](docs/dsu-trial.md) (trial) and
[docs/install.md](docs/install.md) (full flash).

**The GSI builds**

| Build | File | Size | System |
|---|---|---|---|
| `spring` (**default — HyperOS 2**) | `Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip` | 3.1 GB | Android 15 / HyperOS 2, Qualcomm (Snapdragon 6s Gen 3) |
| `gold` | `Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip` | 3.6 GB | Android 15 / HyperOS 3.0.1.0, MediaTek (Dimensity 6080) |
| `pudding` (experimental) | `Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip` | 4.0 GB | Android 16 / HyperOS 3, Qualcomm (Snapdragon 8 Elite Gen 5) |

Get one with `bash scripts/fetch-gsi.sh` (default: spring), or
download by hand from
<https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/>.
**Why spring, not gold:** gold is HyperOS 3.0.1.0 on Android 15
from a MediaTek device — a MediaTek-source GSI drags in MTK
telephony/camera jars and forces the MTK RIL shim chain. Spring is
the actual HyperOS 2 / Android 15 / Qualcomm-source build, and the
m51's vendor is frozen at Android 12, so the smallest system↔vendor
gap wins. Verified: the spring zip is exactly 3,122,721,686 B, MD5
`3e6337d1dd850ae2d0f7d067f8dd191c`, and its `system.img` is
6,232,481,792 B of **ext4** — the DSU filesystem gate is cleared.
A Drive mirror lives at `backups/m51-hyperos/gsi/`. The A71 port's
FoxetGSI build is dead (account + link 404), so Mystic is the only
downloadable route. Verification record:
[docs/gsi-verification.md](docs/gsi-verification.md).

### 7.1 Try it first — DSU trial boot (no wipe, no flash)

DSU (Dynamic System Updates) boots the GSI once as a second,
temporary system. Your installed system and data are untouched, and
a reboot takes you back. If the GSI bootloops, you lose nothing but
time. **Do this before the full flash.**

1. Unlocked bootloader (§3) — the unlock wipes once, but DSU
   itself wipes nothing. Back up first anyway.
2. Get the GSI on the phone (`scripts/fetch-gsi.sh`, then copy the
   zip — or the extracted `system.img` — to the phone). DSU needs
   several GB free on the phone for the second system image.
3. Install **DSU Sideloader** by VegaBobo — from
   [F-Droid](https://f-droid.org/) or
   <https://github.com/VegaBobo/DSU-Sideloader/releases> — and
   **Shizuku** (Play Store) for the easiest mode if the phone is not
   rooted. Root also works; plain ADB mode works too but needs a PC
   command.
4. Open DSU Sideloader, give it read/write permission to a folder
   you create (it stores temporary files such as the extracted
   GSI), select the GSI (`.gz`, `.xz`, `.img`, or `.zip` — if the app
   rejects the Mystic zip, extract `system.img` first and select
   the `.img`). Do not change the GSI file size; let the app handle
   it. Optionally set the userdata size for the dynamic system.
5. Tap **Install** and wait. When it finishes: root mode needs no
   extra step; Shizuku/root mode shows the DSU screen asking you to
   confirm (check notifications); ADB mode prompts you to run a
   command in adb — run it, and the DSU screen appears.
6. Boot the dynamic system from the notification (or the app).
   Test: home screen? Wi-Fi? Calls? Write down what works and what
   does not — that is the test report this project needs.
7. **Getting back: reboot.** That is it. For a long test with many
   reboots, sticky mode keeps booting the dynamic system:
   `adb shell gsi_tool enable` (disable with `disable`).

**If it does not boot:** DSU installs but the phone will not boot
into it → AVB is blocking the unsigned image; flash
`vbmeta_disabled.tar` via Odin and try again. Install fails → free
space (GSI + userdata image). Black screen / bootloop in the GSI →
the Android 12 vendor vs Android 15/16 system gap is the prime
suspect; try the other build (HyperOS 2 first; HyperOS 1 / Android
14 has the smallest vendor gap). Capture a boot log over adb —
`adb logcat` while it tries, or start the live watcher (§10)
before the boot.

**What a DSU boot proves:** the GSI boots on the m51 vendor. It
does **not** prove the full flash works the same way (that path also
depends on TWRP/fastbootd and the super-partition size), and it
does not prove SIM, camera, or fingerprint work. Those are separate
tests.

### 7.2 Full flash — TWRP + fastbootd

Only after a successful trial boot.

1. Do §2–§4 (unlock, TWRP, Format Data). Download the GSI
   (`scripts/fetch-gsi.sh`) and extract `system.img` from the zip
   (`unzip Hyperos-spring-....zip`). The extracted file must be a
   `system.img` — if the archive has none at the top level, stop.
2. In TWRP: Install → flash **Permissiver v5** (SELinux-permissive
   zip the Samsung GSI guides use; verified direct URL in
   [docs/gsi-verification.md](docs/gsi-verification.md) — 1,251,096 B,
   MD5 `73f68347929e484351d2ca1f72360381`). Enforcing SELinux
   otherwise blocks the GSI from booting.
3. In TWRP: Reboot → **Fastboot**. The phone boots into fastbootd
   (Samsung has no native fastboot).
4. Copy `system.img` into your platform-tools folder. From the PC:

```sh
fastboot erase system
fastboot delete-logical-partition product
fastboot delete-logical-partition system_ext
fastboot flash system system.img
fastboot -w
fastboot reboot recovery
```

`product` and `system_ext` are logical partitions inside super;
deleting them frees room for the ~3–4 GB system image. If
`fastboot flash system` fails with a size error, the image does not
fit super as laid out — stop and report it; do not force it.
5. In TWRP: Wipe → Format Data → type `YES`. Reboot → System.
6. First boot takes several minutes. The **setup wizard may be
   dead** (reported on other Samsung HyperOS GSIs). If it is,
   finish setup over adb (standard AOSP setup-skip commands,
   unproven on this build):

```sh
adb shell settings put secure user_setup_complete 1
adb shell settings put global device_provisioned 1
adb reboot
```

7. If it bootloops or black-screens, capture a log before wiping:
   `adb logcat -d > boot_log.txt` while the phone is up, or run the
   live watcher (§10) during the boot attempt.

**Going back to stock:** flash the §6 firmware with Odin
(AP/BL/CP/CSC), then Format Data in stock recovery. That is the
full rollback — it also restores the stock vbmeta. (Knox stays
tripped; that cannot be undone.)

## 8. Flash UN1CA

UN1CA is a One UI port — Samsung's flagship firmware (Galaxy S22
base, One UI 9 / 9.5) rebuilt for the m51, with Galaxy AI, DeX,
KnoxPatch, Play Integrity Fix and its own OTA app. Our builds live
in the sister repo
[kkisdevil/un1ca-universal](https://github.com/kkisdevil/un1ca-universal)
(the universal porter: one manifest + resolver, per-device targets;
upstream is [salvogiangri/UN1CA](https://github.com/salvogiangri/UN1CA),
our m51 target is Arnav's `seventeen` branch, UN1CA 5.4.0).

**Build status (honest):** three builds succeeded (#5, #7, #8).
Latest is **#8** (run 45491802857, 1h 35m, all jobs green): the
performance fix pack **plus** the daemon fix (see below). Artifact
`UN1CA-m51-decrypted`, 10.9 GB, SHA-256
`fe7201a28d6becbd056d4ba27515aecbee091fae8a54f11fd7a403a3d07c020e`,
7-day retention — download by ~2026-12-02. Signed with throwaway
test keys (real keys are an open decision — see §11). **Not yet
flashed or tested on the m51** — the thorough artifact check is
waiting on the download, and the flash itself needs the phone in
hand.

**What the zip does (read before flashing):** it flashes Samsung's
own DXJ2 bootloader/modem firmware, wipes fingerprint enrolments
and dalvik-cache on every flash, and asserts the bootloader is
≥ DXE3. It does **not** touch recovery — the installer deletes
`recovery.img` from the zip. That is the TWRP rule, kept.

**The lag fix pack (in builds #7 and #8):** the S23 firmware on
this 730G lags — thermal caps at 35–38 °C, live blur forced on,
zram off + swappiness 100. The pack relaxes the thermal caps (CPU
cap at 45 °C, GPU 565→650 MHz, game floor 430 MHz), turns blur off
in both places it is forced on, restores zram with swappiness 60,
and neutralises the `carbon_power_engine` daemon that resets
swappiness to 100 at every boot (build #7's effective swappiness
was 100, not 60 — the daemon fix in #8 is what makes 60 stick).
All flagship features are kept; **only blur is removed**, by the
user's own rule. After flashing, wait for background dexopt to
finish (idle ~30 min) before judging speed.

**How the build is made (distilled from the porter + Arnav's and
Mehedi's repos):** the workflow downloads the three stock firmwares
(S21 FE source + m51 target + one more), extracts them, applies the
m51 target (Arnav's `seventeen` @ `f679035535`, vendored in our
repo) and the performance patches, then builds the flashable zip
with `avbroot`/`signapk` signing. Firmware download uses
**samloader-rs v2.0.0** (pinned, SHA-256 verified). The OTA system
(manifest schema, incrementals ~155 MB, fulls ~5.9 GB, `id` =
SHA-256) comes from Mehedi's `static_resources` pattern, retargeted
to our own repo before any release run. Borrowed methods with
credit: SpiderGirl's HIDL→AIDL HAL swaps and FCM 4→5 bump pattern,
ColorOS17's `patch_boot.py`, ProjectArcadeX's `auto_gen` (device
facts derived from the stock firmware itself). What we did **not**
adopt: daemon values as-is, the LostPrime kernel download (same
rate-limit failure as our build #4), SecureFolder neutering and
HDCP debloat, OTA certs as `aosp_testkey` for a release.

**Steps**

1. TWRP installed (§4), backup taken (§2). The phone must already
   be on bootloader ≥ DXE3 (any recent stock or UN1CA build is).
2. Copy the UN1CA zip to the phone (or an SD card).
3. In TWRP: Wipe → Format Data → type `YES` if coming from stock
   or another ROM (encryption differs). If updating from an older
   UN1CA, a dirty flash is usually fine — the zip wipes dalvik
   itself.
4. Install → select the UN1CA zip → flash. Wait — it is a ~5.5 GB
   zip and it also flashes the BL/modem.
5. Reboot → System. First boot takes several minutes. Set up, then
   leave the phone idle ~30 min for dexopt before judging lag.
6. Check the lag fix landed: `adb shell cat /proc/sys/vm/
   swappiness` must read **60** (the effective value, never the
   prop), and `adb shell dumpsys SurfaceFlinger` should show
   60.00 Hz.

## 9. Flash the custom kernel

Our own m51 kernel, built on GitHub from the crDroid sm7150 tree
(4.14.357-openela) with a reviewed `m51_defconfig` (EROFS LZ4-only,
SELinux permissive possible). **Build #8 is green** (run
45372379403, 15m 4s, all 7 gates passed): artifact `m51-kernel-8`,
36.9 MB, SHA-256
`c7086a7e4d05701156138f529da94a06fa898d311aa725a16116be78af8b78ae`,
14-day retention. **Gate 8 — the boot test — has not been done:**
the kernel has never booted on the phone. Treat it as untested
until it has.

**How the build is made:** toolchain pinned to kdrag0n/proton-clang
(commit `9fb011b`, Clang 13.0.0); the workflow installs our merged
`kernel/m51_defconfig` (SHA-256 verified), applies
`patches/kernel/*.patch` (`git apply --check` first), runs `make
m51_defconfig` → `olddefconfig` → build → `savedefconfig`, and
uploads the artifacts. Seven gates: defconfig completes,
olddefconfig keeps every boot-critical symbol, savedefconfig
uploaded, Image.gz-dtb ≥1 MB and <64 MB (the boot partition is
64 MB), kernelrelease exactly `4.14.357-openela`, EROFS_FS +
EROFS_FS_ZIP =y with no LZMA, SECURITY_SELINUX_DEVELOP=y. The
savedefconfig was committed back to the repo after review (909
CONFIG lines). Full record:
[docs/kernel-build.md](docs/kernel-build.md),
[docs/kernel-defconfig-plan.md](docs/kernel-defconfig-plan.md).
Two bugs fixed along the way (NPU Makefile `:=` overwrite,
`__qdf_bug` hidden behind the WLAN_DEBUG guard) are also present in
Mehedi's and LostPrime's trees — do not copy those trees' build
scripts blindly. LostPrime's toolchain comes from a secret URL we
cannot reproduce, and its Nov 11 release is self-flagged corrupted.

**Steps (flash only after reading the Gate 8 warning above)**

1. Get the `m51-kernel-8` artifact from the run page and extract
   the boot image (`Image.gz-dtb` / `boot.img`).
2. In TWRP: Install → **Install Image** → select the boot image →
   flash to the **Boot** partition. (Or pack it into a `boot.tar`
   and flash it in Odin's AP slot.) Only the boot partition is
   written — recovery is untouched.
3. Reboot. Check `adb shell uname -a` shows `4.14.357-openela`
   and `adb shell cat /proc/version` matches.
4. If it does not boot: reboot into TWRP and re-flash the previous
   boot image (stock boot from the §6 AP tar, or the last working
   kernel) — same Install Image step, same partition. Keep the old
   boot image on the phone before you flash the new one.

## 10. Logging — capture what happened

Two tools, one place (`tools/m51-logger/` — full guide:
[docs/LOGGING-GUIDE.md](docs/LOGGING-GUIDE.md)).

- **Snapshot — `collect-logs.sh` (PC over ADB) or
  `collect-logs-termux.sh` (on the phone).** One timestamped bundle
  (MANIFEST + SUMMARY + raw files, packed as `.tar.gz`): kernel
  (dmesg, pstore, last_kmsg), boot + recovery (cmdline, boot
  reason, TWRP logs), system (logcat all 6 buffers, dumpsys),
  camera (CamX lines), CPU/GPU (thermal zones, frequencies, kgsl,
  backlight nodes), RAM (meminfo, zram, PSI, LMK — effective
  swappiness from `/proc/sys/vm/swappiness`, never the prop). One
  persistent ADB connection for the whole run; read-only; root-only
  collectors are skipped and recorded, never forced.
- **Live watcher — `watch-logs.sh` (PC) or
  `watch-logs-termux.sh` (on the phone).** The stream, not a
  snapshot: continuous logcat, one session dir per device
  connection (one per boot attempt — a bootloop never overwrites
  the previous attempt), dmesg/getprop/DSU snapshots at every
  connect, rotation past `--max-mb`. Start the PC watcher **before**
  the boot you want to catch. The on-device watcher uses
  `logcat -f` rotation and is for the running system only — it dies
  with the system on a GSI boot. If the device never reaches adb,
  there are no live logs; say so, do not invent them.

## 11. Project status — everything, honestly

| Track | Status | Evidence |
|---|---|---|
| HyperOS GSI (this repo) | Spring GSI verified + mirrored; DSU trial **not started** (user chose the reverse-engineering track first) | [docs/gsi-verification.md](docs/gsi-verification.md); Drive `backups/m51-hyperos/gsi/` |
| UN1CA ROM (sister repo) | Build #8 green; **not flashed/tested**; artifact check owed | [un1ca-universal](https://github.com/kkisdevil/un1ca-universal); §8 |
| Custom kernel | Build #8 green (7/7 gates); **boot test owed** | [docs/kernel-build.md](docs/kernel-build.md); §9 |
| Lights HAL | Forked, no-op light committed; build run #27 in flight | [android_hardware_samsung](https://github.com/kkisdevil/android_hardware_samsung); [docs/re-lights.md](docs/re-lights.md) |
| Fingerprint | RE done: AIDL v4, two-prop fix; **not tested on device** | [docs/re-fingerprint.md](docs/re-fingerprint.md) |
| RIL / IMS / VoLTE | **Next RE target, not started** — the #1 daily-driver blocker | [docs/port-plan.md](docs/port-plan.md) Phase 3 |
| Stock firmware | DXJ1 INS downloaded, verified, on Drive | [docs/FIRMWARE.md](docs/FIRMWARE.md); §6 |
| Logger + live watcher | Built, tested (25/25 + 13/13 mock checks) | [tools/m51-logger/README.md](tools/m51-logger/README.md); §10 |
| Mercury rename tool | Built, real decompile proven; live test owed | `tools/mercury-rename/`; key via env only, never in repo |
| Linux / dual-boot | Research stage, no boot yet | [m51-linux-boot](https://github.com/kkisdevil/m51-linux-boot), [m51-dualboot](https://github.com/kkisdevil/m51-dualboot) |

**The governing problem is HIDL vs AIDL, not VNDK.** The m51
vendor is FCM 6, inside Android 15's span — HyperOS 2 still
tolerates the HIDL vendor. HyperOS 3 tooling refuses HIDL-only
pre-Android-13 vendors: research-only. Top gaps, in order:
RIL/IMS/VoLTE (Floss IMS per Indian carrier; emergency calls 112
unimplemented), camera (GCam + smali shim; Xiaomi Camera dropped),
side fingerprint (AIDL v4 — see §11 table), SELinux + the HyperOS 3
cliff, display/lights/brightness (RRO overlay + backlight
`panel0-backlight`, sysfs range 0..13510 — not 255). Honest limits:
Widevine L1→L3, Knox lost, no OTA, HyperOS 3 may never be a daily
driver. Full architecture: [docs/reverse-engineering.md](docs/reverse-engineering.md),
[docs/port-plan.md](docs/port-plan.md).

**Vendor blobs (913, frozen):** 29 source-built in tree, 30 with an
open replacement, **732 binary-only (80%)**, 151 firmware/config/
data. Blobs are compiled binaries — decompiling gives disassembly,
not source; clean-room rebuilding works for small pieces, not at
this scale. Full audit: [docs/blob-audit.md](docs/blob-audit.md).

**Forks (Phase 0, all under kkisdevil):** device m51
(`55df7b4a`), a71-common (`48e5e36e`), kernel sm7150 from crDroid
16.0 (`4d83f24b`), vendor m51 (`de409289`), vendor a71-common
(`407f21e5`), hardware/samsung (lineage-22.2, `0365e8bd`). Pins:
[trees/manifest.json](trees/manifest.json). The trees are frozen
since 2025-04-29 — the port starts from a takeover, not a living
upstream.

### What every repo we studied taught us — distilled, with the warnings

This is the cut-to-clear summary of **all** the repos shown to us
(GitLab + GitHub). Each line says what to take and what not to do.

- **myghi63 (LineageOS/crDroid for m51)** — his install walkthrough
  is the model for §2–§6 above (backup, log out, OEM unlock,
  Download Mode, Odin, fast recovery catch, wipe, sideload,
  optional gapps/kernel/Magisk). Take: APatch as a root method (§5),
  the recovery-update warning (§4), own-keys `user` builds passing
  basic integrity (the template for our open signing-keys
  decision), the sunfish thermal-engine.conf as a second thermal
  reference, the proximity-sensor bug on A16 trees (needs a power
  button press to wake — on the HyperOS test checklist). Do NOT
  take: his LineageOS recovery (replaces TWRP — mutually exclusive),
  his vbmeta-on-USERDATA Odin step (unusual, unverified), his
  branch-floating manifests (not reproducible — ours pin SHAs),
  swappiness 180 as a value (A/B-test candidate only; his own
  changelog admits background apps get killed), the "PRIME KERNEL
  IS NOT SUPPORTED" warning (unidentified — no such kernel found,
  do not cite it). His M51 work ended June 2026; he now builds for
  POCO F7. Vanadium WebView swap, MicroG wiring and Cloudflare
  probes are patterns for a *future* LineageOS m51 build only —
  not for UN1CA or the GSI.
- **Mehedi (UN1CA-SM7150, alternative SM7150 source)** — Take:
  samloader-rs v2.0.0, dynamic smali-path resolution, the OTA
  system. Do NOT adopt wholesale: no auto-builds, kernel from
  LostPrime releases, SecureFolder compromise check neutered, HDCP
  provisioning debloated, fingerprint position hardcoded
  "53.45,13.25", OTA certs are `aosp_testkey`. His M51-Device-Tree
  is a DXJ2-era stock dump — a diff reference, **do not flash
  anything from it**. His M51-FIRMWARES holds 27 DXJ2
  bootloader/modem blobs as **raw partition images, not Odin
  firmware — flashing any is brick-risky**. His TWRP-Recovery-
  Builder is a valid fallback to rebuild m51 TWRP (twrp-12.1
  manifest) — build only, never flash without a say-so.
- **SpiderGirl-OS (AstroROM fork, One UI 8.5)** — the only repo with
  proven-green m51 builds recently (5/5, Oct 2026). Take: the
  HIDL→AIDL HAL swap patterns (lights, vibrator, snap camera from
  S22/r9q blobs), the FCM 4→5 bump recipe, the vendored samloader
  binary. Do NOT take: its RIL "fix" (only a 1.4→1.5 manifest string
  change), its kernel (unpinned raw URL + third-party zip, no hash).
- **ExtremeROM-M51 / MintOS-M51 (One UI 7, frozen)** — corroboration
  only: 60 Hz pinned, siop/dvfs names match ours. MintOS keeps the
  full ArcSoft camera stack (reference copy if UN1CA camera work
  needs those snap libs); its 67 MB prebuilt boot.img is a black box
  — never flash without a TWRP backup and a say-so.
- **Arnav (UN1CA-SM7150 — our primary m51 source)** — Take: the
  `seventeen` target, the NFC init-rc fix (already in builds
  #5/#7/#8), the OTA manifest schema, the Qwen download pattern.
  His Hyper371 (HyperOS 3.1, docs-only, first boot pending) gives
  us the verification-record format, offline `secilc`
  combined-policy compile, the VINTF parser precheck, partition
  layout numbers, and the byte-for-byte EFS backup gate. His
  ColorOS17 port gives us `patch_boot.py`, the vendor fstab recipe,
  **recovery-overwriter removal (the mechanism that keeps TWRP)**,
  EROFS repack with file-contexts + super sizing, and the VoLTE
  bypass as a fallback. His OneOS gives us the black-screen fix
  (panel node `panel0-backlight`, `actual_brightness`,
  `bl_power`, HWC off) and the Samsung-IMS-in-guest doc (third IMS
  approach). Traps in his repos: unpinned toraidl binaries with no
  hashes, `my_*` partition bloat, KernelSU on by default,
  Hyper371's vendor FCM 5 vs our audit's 6 (open check).
- **MonsterROM (third UN1CA fork)** — do NOT switch to it and do NOT
  build it for the m51: no m51 target, wrong SoC family (Exynos
  2100, kernel 5.15), needs a self-hosted runner with 150 GiB disk,
  and its own README admits the "One UI 9.5" branding is cosmetic
  with physical boot unproven even for its qualified targets. Take
  only method: payload checksums + guarded cohorts, a single
  `customize.sh` entry point, experimental profiles default-off,
  pinned ShellCheck with SHA-256 verification, status docs that
  separate host-tested from device-proven.
- **ProjectArcadeX (script-based Samsung patcher)** — zero m51 /
  sm7150 mentions; take the methods: `auto_gen` (derive device
  facts from the stock firmware itself), vendored samfirm.js, md5
  marker caching, Knox smalipatches as study material.
- **Upstream (salvogiangri/UN1CA, a71-devs, crDroid, LineageOS,
  MysticGSI, topjohnwu, VegaBobo)** — the base system, the trees,
  the kernel, the HAL sources, the GSI, the root tool, the DSU
  installer. Credited in §16 and [CREDITS.md](CREDITS.md).

**Open decisions (not decided for you):** real signing keys vs
test keys; whether to flash build #8 on the m51; when to start the
DSU trial; whether a spare test m51 exists; the myghi63 vendor
lineage-23.0 vs frozen 22.2 diff; the Hyper371 FCM 5 vs 6 question;
AIDL vibrator vs AIDL media converter.

## 12. Known issues

Expected — none confirmed on m51 yet (from HyperOS GSI reports on
other Samsung models: S10, A21s, A54, A71). Full list:
[docs/known-issues.md](docs/known-issues.md).

| Issue | Status on m51 |
|---|---|
| Camera app not installed | Expected — use GCam as a workaround |
| SIM / RIL not working for some | Expected — biggest daily-driver risk |
| VoLTE / VoWiFi | Expected broken |
| Setup wizard dead | Expected — finish setup over adb (§7.2 step 6) |
| Brightness bug, flashlight, status-bar glitches, gesture nav partly broken | Expected |
| Side fingerprint sensor | Unknown — RE says AIDL v4 + two props; untested |
| Play Integrity / banking apps | Expected to fail (unlocked bootloader + GSI) |
| Proximity sensor (A16 trees) | Reported on myghi63's trees: not fully functional, needs a power button press to wake — on the test checklist |
| 112 emergency calls | Unimplemented (Floss IMS gap) — #1 daily-driver blocker |

## 13. Repo layout

```text
m51-hyperos/
├── README.md                  # this file — everything on one page
├── CREDITS.md                 # everyone whose work this builds on
├── LICENSE                    # GPL-3.0
├── docs/
│   ├── install.md             # full GSI flash (TWRP + fastbootd), deep version
│   ├── dsu-trial.md           # DSU trial boot (do this first), deep version
│   ├── FLASHING-GUIDE.md      # stock firmware via Odin, deep version
│   ├── FIRMWARE.md            # DXJ1 record, hashes, Drive paths
│   ├── LOGGING-GUIDE.md       # collector + live watcher guide
│   ├── known-issues.md        # expected broken things + workarounds
│   ├── faq.md                 # questions everyone asks
│   ├── reverse-engineering.md # phase 1: trees, HyperOS structure, gap table
│   ├── port-plan.md           # phase 1: port architecture + work phases
│   ├── tree-takeover.md       # phase 0: pinned trees, audit, fork plan
│   ├── blob-audit.md          # the 913 blobs, bucket by bucket
│   ├── blob-refresh.md        # why the frozen blobs are the base
│   ├── kernel-build.md        # kernel build record + gates
│   ├── kernel-defconfig-plan.md # the merged defconfig plan
│   ├── re-lights.md           # lights HAL reverse-engineering
│   ├── re-fingerprint.md      # fingerprint HAL reverse-engineering
│   ├── twrp-user-check.md     # the TWRP on our phone, verified
│   ├── BUILD-GUIDE.md         # the 6-layer build guide
│   ├── gsi-verification.md    # GSI + Permissiver verification record
│   └── devices/               # per-device procedures (see §14)
├── trees/
│   └── manifest.json          # machine-readable pins + fork records
├── scripts/
│   ├── fetch-gsi.sh           # download a HyperOS GSI (spring default)
│   ├── fetch-firmware.sh      # download + verify + Drive-upload the stock firmware
│   ├── firmware-logger.sh     # the firmware logger
│   ├── upload-gsi-drive.sh    # mirror the GSI to Drive in 1 GiB parts
│   └── verify-device.sh       # go / no-go prerequisite check over adb
├── tools/
│   ├── m51-logger/            # collector + live watcher (see §10)
│   └── mercury-rename/        # Ghidra + Mercury 3 auto-rename decompiler tool
├── kernel/
│   └── m51_defconfig          # reviewed savedefconfig (909 CONFIG lines)
├── patches/
│   └── kernel/                # kernel patches (drm-sde, NPU, qdf)
├── vendor/
│   ├── README.md              # vendored pieces (our own implementations)
│   ├── FETCH-SPEC.md          # pinned fetch spec for everything too big/proprietary
│   ├── scripts/               # patch_boot, patch_fstab, vintf_precheck, ...
│   ├── props/                 # fingerprint-side.prop, volte-bypass.prop
│   ├── sepolicy/              # m51.cil template
│   └── tests/                 # 22 checks, all passing
└── .github/workflows/
    ├── build-kernel.yml       # kernel build (gates 1–7)
    ├── test.yml               # dry-runs the scripts (no downloads)
    └── validate.yml           # shellcheck + docs-link checks on push
```

The lights HAL workflow lives in the fork repo
(`kkisdevil/android_hardware_samsung`, `build-lights-hal.yml`),
not here. The UN1CA porter lives in its own repo
([kkisdevil/un1ca-universal](https://github.com/kkisdevil/un1ca-universal)).

## 14. Per-device procedures

The procedures on this page are written for the m51. They are
also saved separately, **one folder per device**, so each device's
exact methods live in exactly one place and a new device gets the
same shape instead of a copy-paste:

```text
docs/devices/
├── README.md                  # the layout + how to add a device
├── _template/                 # empty procedure files for a new device
│   ├── unlock-bootloader.md
│   ├── flash-twrp.md
│   ├── root.md
│   ├── flash-stock.md
│   ├── flash-gsi.md
│   ├── flash-un1ca.md
│   └── flash-kernel.md
└── m51/                       # SM-M515F — the complete procedures
    ├── README.md              # device card + links
    ├── unlock-bootloader.md
    ├── flash-twrp.md
    ├── root.md
    ├── flash-stock.md
    ├── flash-gsi.md
    ├── flash-un1ca.md
    └── flash-kernel.md
```

Rule: the per-device file is the canonical copy for that device;
this README mirrors it on the single page. When a procedure
changes, update **both** — a fix in one place only is a bug waiting
for the next reader.

## 15. Troubleshooting

- **Odin does not detect the phone (`ID:COM` stays empty).**
  Reinstall the Samsung USB Driver, try another USB port (on the
  PC itself, not a hub) and another data cable. Confirm Download
  mode — not just charging.
- **Odin shows FAIL.** Read the exact line where the log stopped.
  Wrong model/region firmware, corrupted download (re-check the
  hashes), bad cable, dying battery. Re-enter Download mode and
  retry with a verified download.
- **`SW REV CHECK FAIL`.** The package's bootloader is older than
  the phone's (anti-rollback). DXJ1 is bootloader 6.
- **Stuck on the Samsung logo / bootloop after flashing.** Boot
  into recovery, wipe cache, then factory reset. Still stuck →
  re-flash the full package with the **CSC** file (wipe).
- **Phone boots but has no signal / wrong region features.** Wrong
  CSC — re-flash with the INS package.
- **TWRP is gone after a flash.** Expected after a full stock AP —
  re-flash it (§4). If it disappears after a normal boot, you
  booted to system before recovery caught it; re-flash and boot
  straight to recovery.
- **DSU installs but will not boot into the GSI.** AVB is blocking
  the unsigned image — flash `vbmeta_disabled.tar` and retry.
- **GSI black screen / bootloop.** Vendor gap is the prime suspect;
  try the other build (HyperOS 2 first). Capture a boot log (§10).
- **Setup wizard dead on first GSI boot.** Finish setup over adb
  (§7.2 step 6).
- **Root lost after an OTA.** Expected — OTAs remove root. Re-root
  (§5); do not take OTAs on a rooted phone.
- **Banking app fails after root / GSI.** Play Integrity, not a
  broken flash. UN1CA ships a Play Integrity Fix; on stock, PIF /
  Shamiko-style modules exist but are not verified by us.

## 16. Credits

See [CREDITS.md](CREDITS.md) for the full list. In short: Xiaomi
(HyperOS itself — this project redistributes none of it; you
download the GSI from the community sources), salvogiangri (UN1CA),
Arnav (UN1CA-SM7150 `seventeen`, Hyper371, ColorOS17, OneOS),
Mehedi (UN1CA-SM7150 `sixteen`, OTA system, static_resources),
myghi63 (LineageOS/crDroid guides, APatch recommendation, thermal
reference), a71-devs (device trees + vendor), crDroid (kernel
sm7150), LineageOS (hardware/samsung HAL sources), MysticGSI (the
GSI builds), SpiderGirl-OS (HIDL→AIDL swaps), ExtremeROM / MintOS
(corroboration + camera stack), SameerAlSahab / ProjectArcadeX
(`auto_gen` + tooling patterns), ditternation / devcore94
(MonsterROM methods), topjohnwu (Magisk, samloader-rs), VegaBobo
(DSU Sideloader), and everyone named in CREDITS.md. If you use
anything from this repo, credit the people above — the work is
theirs; this repo only assembles it.

## License

GPL-3.0 — see [LICENSE](LICENSE). The scripts and docs in this repo
are free software; the HyperOS system images are Xiaomi's
proprietary firmware repackaged by the community, and their own
terms apply.
