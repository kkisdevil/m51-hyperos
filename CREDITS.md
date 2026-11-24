# Credits — m51-hyperos

This project stands on other people's work. Nothing here would exist
without them. If you use this repo, credit them too.

## The GSI itself

- **Mystic GSI project** — the community HyperOS Generic System Images
  this project downloads and flashes. SourceForge project
  `mystic-gsi-updates`, HyperOS folder:
  <https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/>
  All builds are arm64 AB variants, repackaged from official Xiaomi
  firmware. No official Xiaomi involvement.
- **Xiaomi / HyperOS** — HyperOS itself is Xiaomi's firmware. This repo
  redistributes none of it; you download the GSI from the community
  sources above.
- **xiaomi.eu team** — the HyperOS firmware the A71 precedent port was
  built from.
- **FoxetGSI** — creator of the HyperOS GSI build that booted on the
  Galaxy A71 (`HyperOS-AB-15-2025-06-15-FoxetGSI`). The build's GitHub
  release link is dead: the FoxetGSI account returns 404 as of
  2026-11-24, so the file cannot be downloaded from there anymore.

## The m51 / SM7150 community

- **seelenchik** — author of "[GSI] HyperOS 2 (xiaomi.eu) port for Samsung
  Galaxy A71 SM-A715F" (XDA, 2025-06-29), the verified A71 precedent this
  project is modelled on, and of the MitaUX One UI 7 port for the M51.
- **Legofan** — told seelenchik which vendor to use for the A71 HyperOS
  port; also an A71 ROM maintainer.
- **salvo_giangri / UN1CA** — UN1CA for the A71, credited in the A71
  HyperOS port; the UN1CA porter this project sits next to is
  <https://github.com/kkisdevil/un1ca-universal>.
- **a71-devs** — the device trees the m51's whole custom-ROM scene
  (LineageOS, crDroid, /e/OS) builds on.
- **ApiYoshi** — kernel work on the SM7150 family (mentioned in XDA
  discussion of HyperOS boot attempts on 4.14-kernel Samsung devices).

## Tools and guides

- **TWRP Team** — Team Win Recovery Project, the custom recovery the
  full flash path depends on. Unofficial m51 build:
  XDA "[RECOVERY][UNOFFICIAL] TWRP for Galaxy M51 (Snapdragon)".
- **VegaBobo — DSU Sideloader** — the app that makes the no-wipe trial
  boot possible: <https://github.com/VegaBobo/DSU-Sideloader>
  (Apache-2.0). Also the **Shizuku** project, which DSU Sideloader uses
  as one of its operation modes.
- **DroidWin** — "How to Flash HyperOS 2 Android 15 GSI on Samsung",
  the generic Samsung GSI guide this project's install steps follow:
  <https://droidwin.com/how-to-flash-hyperos-2-android-15-gsi-on-samsung/>
- **MagiskZip** — "How to Install GSI ROMs on Samsung Devices Without
  TWRP" (the DSU route):
  <https://magiskzip.com/how-to-install-gsi-roms-on-samsung-devices-without-twrp/>
- **phhusson / Treble experimentations** — the GSI ecosystem (Treble,
  DSU, the GSI list) this whole approach rests on.
- **northstark-lvy / XMAPort** — the automated HyperOS porter
  (<https://github.com/northstark-lvy/xmaport>). It is Xiaomi→Xiaomi
  only and cannot port to the m51, which is why this project is
  GSI-based — credited here because it was evaluated, not used.
- **Orthoxodus / Dachoni03 — Rakija-GSI-Tool** — a tool that builds GSI
  ports from OEM firmware URLs (`url2GSI.sh <URL> -- ab HyperOS`):
  <https://github.com/Orthoxodus/Rakija-GSI-Tool>. An alternative route
  for building a HyperOS GSI yourself; not used by this project.
- **w111user — hyperos-gsi-samsung-galaxy-a035f** — the HyperOS 1 port
  project for the Galaxy A03 (Samsung Android 11 vendor, kernel 4.14),
  a methodology precedent for making HyperOS work on Samsung hardware
  it was never designed for:
  <https://github.com/w111user/hyperos-gsi-samsung-galaxy-a035f>

## Precedent reports (other Samsung models)

- XDA, "HyperOS 2.0.9.0 for Galaxy S10 Series" — S10 boots on Mystic GSI.
- XDA, "[SHARED] HyperOS 2.0.9 for Samsung Galaxy A21s" — A21s boots,
  with the bug list this project's known-issues doc draws on.
- XDA, "How to install hyperos on A546E and all variants (Binary 7+)" —
  A54 DSU method; also where the (now dead) FoxetGSI build link was quoted.

## This repo

- **kkisdevil / Kartik Deepak Sormare** — this repo, its scripts and docs
  (GPL-3.0). Research: `research/07-hyperos-m51.md` in
  [un1ca-universal](https://github.com/kkisdevil/un1ca-universal).
- **The user-reported Telegram m51 boots** — HyperOS boots on the m51
  reported on Telegram via GSI. Telegram groups are not web-indexed, so
  no group, link, or build can be credited by name here; the report is
  recorded as user-reported and unlinked in the README. If you are one of
  the people who booted it, please say so — you belong in this file.
