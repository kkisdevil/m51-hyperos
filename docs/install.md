# Full flash — install HyperOS on the m51 (TWRP + fastbootd)

> **Do the [DSU trial](dsu-trial.md) first.** If the GSI does not boot
> as a trial, flashing it will not go better — and flashing wipes your
> data. This guide is for after a successful trial boot.

> **Warning.** Unlocking the bootloader wipes the phone, trips Knox
> permanently, drops Widevine to L3, and loses Samsung Pay / Secure
> Folder. Flashing the wrong image can brick the phone. Have a full
> stock-firmware backup and a working Odin restore path before you start.
> You do this at your own risk.

## 0. What you need

- Galaxy M51 **SM-M515F** (international). No other model is covered.
- A PC with Android platform-tools (`adb`, `fastboot`) and Odin (for
  TWRP + restore).
- Unofficial **TWRP for Galaxy M51** — XDA thread
  "[RECOVERY][UNOFFICIAL] TWRP for Galaxy M51 (Snapdragon)", plus
  `vbmeta_disabled.tar` and `multidisabler` (both named in that thread).
- **Permissiver v5** — the SELinux-permissive zip the Samsung GSI guides
  use. Download it from the link in the DroidWin guide below; no direct
  download URL is published in this repo because none was verified.
- The HyperOS GSI — get it with `bash scripts/fetch-gsi.sh`
  (HyperOS 2 default; see [fetching the GSI](#1-fetch-the-gsi)), or
  download it by hand from the links there.
- ~10 GB free on the PC, a charged phone, and a USB cable.

Guides this document follows:

- DroidWin, "How to Flash HyperOS 2 Android 15 GSI on Samsung":
  <https://droidwin.com/how-to-flash-hyperos-2-android-15-gsi-on-samsung/>
- XDA, "[RECOVERY][UNOFFICIAL] TWRP for Galaxy M51 (Snapdragon)":
  <https://xdaforums.com/t/recovery-unofficial-twrp-for-galaxy-m51-snapdragon.4559657/>

## 1. Fetch the GSI

```sh
bash scripts/fetch-gsi.sh            # HyperOS 2 (Android 15), default
bash scripts/fetch-gsi.sh --list     # show every known build
```

Default build (verified on the SourceForge listing, 2026-11-24):

| Build | File | Size | Android |
|---|---|---|---|
| `gold` (default) | `Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip` | 3.6 GB | 15 / HyperOS 2 |
| `spring` | `Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip` | 3.1 GB | 15 / HyperOS 2 |
| `pudding` (experimental) | `Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip` | 4.0 GB | 16 / HyperOS 3 |

Download source for the Mystic builds:
<https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/>

> **Note on the A71 port's build.** The Galaxy A71 HyperOS 2 port used
> a FoxetGSI build (`HyperOS-AB-15-2025-06-15-FoxetGSI.7z`), but the
> FoxetGSI GitHub account and its release link now return 404 (checked
> 2026-11-24) — the file cannot be downloaded from there anymore, so it
> is not listed as a candidate above. If a mirror surfaces, it can be
> added back; until then the Mystic builds are the only downloadable
> route in this repo.

Extract `system.img` from the archive (the Mystic zips are standard
zips):

```sh
unzip Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip
```

The extracted file must be a `system.img`. If the archive does not
contain one at the top level, stop — do not flash anything else from it.

## 2. Back up, then unlock the bootloader

1. Back up everything. Unlocking wipes the phone.
2. Enable Developer options → **OEM unlocking** and **USB debugging**.
3. Boot into Download mode and confirm the unlock on screen.
4. The phone wipes itself and reboots. Set it up minimally (or skip
   setup) — you only need adb working.

## 3. Flash TWRP

From the XDA TWRP thread for the m51:

1. Flash `vbmeta_disabled.tar` **and** the TWRP image via Odin
   (TWRP in the AP slot).
2. Boot into TWRP, run `multidisabler`.
3. **Format Data** (Wipe → Format Data → type `YES`).

Do not skip the vbmeta step: a signed vbmeta will refuse to boot the
unsigned GSI.

## 4. Flash Permissiver v5

In TWRP: Install → select the Permissiver v5 zip → flash it. SELinux
enforcing otherwise blocks the GSI from booting — this is the step the
generic Samsung GSI guides all insist on.

## 5. Flash the GSI via fastbootd

Samsung has no native fastboot, so this goes through TWRP's fastbootd:

1. In TWRP: Reboot → **Fastboot**. The phone boots into fastbootd.
2. Copy `system.img` into your platform-tools folder.
3. From the PC:

```sh
fastboot erase system
fastboot delete-logical-partition product
fastboot delete-logical-partition system_ext
fastboot flash system system.img
fastboot -w
fastboot reboot recovery
```

4. In TWRP: Wipe → Format Data → type `YES`.
5. Reboot → System.

> **Check before you run step 3.** The exact partition steps must match
> the m51's actual layout — `product` and `system_ext` are logical
> partitions inside the super partition on this device, and deleting them
> frees room for the ~3–4 GB system image. If `fastboot flash system`
> fails with a size error, the image does not fit the super partition
> as laid out — stop and report it; do not force it.

## 6. First boot

- First boot takes several minutes. Be patient.
- The **setup wizard may be dead** (reported on other Samsung HyperOS
  GSIs). If it is, finish setup over adb — these are the standard AOSP
  setup-skip commands, **unproven on this build**:

```sh
adb shell settings put secure user_setup_complete 1
adb shell settings put global device_provisioned 1
adb reboot
```

- If it bootloops or black-screens, capture a log before wiping:
  `adb logcat -d > boot_log.txt` while the phone is up, or
  `adb logcat` during the boot attempt. A boot log is the single most
  useful thing for diagnosing a failed boot.

## 7. Going back to stock

Flash the stock firmware for SM-M515F with Odin (AP/BL/CP/CSC), then
Format Data in stock recovery. That is the full rollback — it also
restores the stock vbmeta. (Knox stays tripped; that cannot be undone.)

## What is still unknown

- Whether the Mystic HyperOS 2 build boots on the m51 at all (DSU trial
  pending; Telegram reports say GSI boots have happened, but no build or
  fix list is public).
- Whether SIM/calls/data work on the Android 12 vendor.
- Whether the side fingerprint sensor works.
- Whether HyperOS 3 boots at all on the Android 12 vendor.
- Whether the ~4 GB system image fits the m51's super partition as
  laid out.

See [known-issues.md](known-issues.md) and [faq.md](faq.md).
