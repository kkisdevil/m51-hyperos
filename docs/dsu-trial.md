# DSU trial boot — try HyperOS without flashing it (do this first)

DSU (Dynamic System Updates) boots a GSI once, as a second, temporary
system. Your installed system and data are untouched, and a reboot takes
you back. If the GSI bootloops, you lose nothing but time.

This is the recommended first step before the full flash in
[install.md](install.md). It is **unproven on the m51** — DSU needs
dynamic partitions (the m51 has them) and an unlocked bootloader, and it
does not work on every Samsung build. If the trial fails, that is useful
information too: report it.

## What you need

- Galaxy M51 (SM-M515F) with an **unlocked bootloader**.
  Unlocking wipes the phone once and trips Knox permanently — do the
  backup first, even for a trial. (DSU itself does not wipe anything, but
  the unlock that enables it does.)
- The HyperOS GSI file, downloaded on the phone or on a PC and copied to
  the phone. Get it with `bash scripts/fetch-gsi.sh` (HyperOS 2 default),
  or see [install.md](install.md) for the direct links.
  The GSI zip is ~3–4 GB; DSU also needs several GB of free space on the
  phone for the second system image.
- **DSU Sideloader** by VegaBobo — install it from
  [F-Droid](https://f-droid.org/) or from the
  [GitHub releases](https://github.com/VegaBobo/DSU-Sideloader/releases).
  (Apache-2.0, 2,385 stars on GitHub, verified 2026-11-24.)
- **Shizuku** (from the Play Store) — the easiest operation mode if the
  phone is not rooted. Root also works. Plain ADB mode works too but
  needs a PC command.

## Steps

1. Install DSU Sideloader. On first launch, give it read/write
   permission to a folder you create — this folder stores temporary
   files such as the extracted GSI.
2. Select the GSI to install. Accepted formats: `.gz`, `.xz`, `.img`,
   and `.zip` (DSU packages only — the Mystic GSI zips are standard
   zips containing `system.img`; if the app rejects the file, extract
   `system.img` from the zip first and select the `.img`).
3. Customise the install if you want — for example the userdata size
   for the dynamic system. Do not change the GSI file size; let the app
   handle it.
4. Tap **Install** and wait. It takes a while.
5. When it finishes, the next step depends on the operation mode:
   - **Built-in installer enabled (root):** no extra step.
   - **Shizuku / root mode:** the DSU screen appears and asks you to
     confirm the installation; check your notifications — DSU should
     start installing the GSI.
   - **ADB mode:** you are prompted to run a command in adb; run it,
     and the DSU screen appears asking you to confirm.
6. Once the dynamic system is ready, boot it from the notification, or
   directly from the app if your operation mode supports it.
7. Test: does it reach the home screen? Does Wi-Fi work? Do calls work?
   Write down what works and what does not — that is the test report
   this project needs (see [known-issues.md](known-issues.md)).

## Getting back

Reboot. That is it — a reboot returns you to your installed system.
Nothing was modified.

For a long test with many reboots, **sticky mode** makes the phone keep
booting into the dynamic system instead of the installed one:

```sh
adb shell gsi_tool enable     # from a PC, or
gsi_tool enable               # from a local adb shell, or
su -c 'gsi_tool enable'       # from a rooted shell on the device
```

Disable it the same way with `disable` instead of `enable`.

## If it does not boot

- **DSU installs but the phone does not boot into it:** AVB is probably
  blocking the unsigned image. Flash a disabled vbmeta
  (`vbmeta_disabled.tar` via Odin) and try again.
- **Install fails:** DSU needs enough free space (the GSI plus a userdata
  image). Free space and retry. The app's installation diagnostics can
  name common errors.
- **Black screen / bootloop in the GSI:** the vendor gap (Android 12
  vendor vs Android 15/16 system) is the prime suspect. Try the other
  GSI build — HyperOS 2 first, and if that fails, HyperOS 1 (Android 14)
  has the smallest vendor gap. A boot log over adb (`adb logcat`) is the
  most useful thing you can capture; see [faq.md](faq.md).

## What this does not prove

A successful DSU boot proves the GSI *boots* on the m51 vendor. It does
not prove the full flash will work the same way (the flash path also
depends on TWRP/fastbootd and the super-partition size), and it does not
prove SIM, camera, or fingerprint work. Those are separate tests.

## Sources

- DSU Sideloader (VegaBobo): <https://github.com/VegaBobo/DSU-Sideloader>
- "How to Install GSI ROMs on Samsung Devices Without TWRP" (MagiskZip):
  <https://magiskzip.com/how-to-install-gsi-roms-on-samsung-devices-without-twrp/>
- Android DSU documentation: <https://developer.android.com/topic/dsu>
