# m51-hyperos — HyperOS for the Samsung Galaxy M51 (SM-M515F)

HyperOS on the Galaxy M51 via a community **Generic System Image (GSI)**.
An experiment, not a daily driver (yet).

> **Status: unproven on m51 — but not purely theoretical.**
>
> No HyperOS port exists for the m51, and no *public* report (XDA, GitHub,
> YouTube) of HyperOS booting on one was found in research (2026-11-24).
> **But HyperOS boots on the m51 have been reported on Telegram, via GSI.**
> Telegram groups are not web-indexed, so no link can be given — the report
> is user-reported and unlinked. That is why this project treats the GSI
> path as **proven-in-principle** rather than purely theoretical: the remaining
> question is not "can it boot at all" but "how well does it work, and with
> which GSI build and fixes".
>
> Closest *verified* precedent: the sister device Galaxy A71 (same
> Snapdragon 730G / SM7150 platform, same device-tree family) boots
> HyperOS 2 — seelenchik's "[GSI] HyperOS 2 (xiaomi.eu) port for Samsung
> Galaxy A71 SM-A715F" (XDA, Samsung Galaxy A71 ROMs, 2025-06-29, 40
> replies), built on a FoxetGSI image and described by its author as hard
> to flash, unstable, and no longer updated. The m51 shares the A71's
> platform and trees, so the same method is expected to apply — **unproven
> on m51 until someone tests it**.

## What this is

- A **GSI-based** HyperOS bring-up for the m51: take a community HyperOS
  system image (arm64 **AB** variant), flash it over the m51's stock
  vendor with TWRP + fastbootd, and document what works and what does not.
- The recommended first step is a **DSU Sideloader trial boot** — it boots
  the GSI once without replacing the installed system, so a bootloop costs
  nothing. See [docs/dsu-trial.md](docs/dsu-trial.md).
- The recommended first GSI is **HyperOS 2 (Android 15)**, not HyperOS 3:
  the m51's vendor is frozen at Android 12 (VNDK 31, kernel 4.14), and the
  smaller the system↔vendor version gap, the fewer HAL surprises. HyperOS 3
  (Android 16) is the second, riskier try.

## What this is NOT

- **Not a from-source device port.** There is no such port for the m51 and
  nobody is building one. A real port would need the m51 vendor blobs, the
  `a71-devs` device trees, and porting Xiaomi's HyperOS framework/apps onto
  Samsung's vendor — a multi-week project with no guarantee of a
  daily-driver result.
- The only automated HyperOS porter, **XMAPort**, is Xiaomi→Xiaomi only: it
  migrates a source device's HyperOS partitions onto a target device's
  *official HyperOS base ROM*. The m51 has no official HyperOS base ROM,
  so XMAPort cannot produce an m51 build.
- This repo builds **no ROM** and downloads **no firmware** in CI. The
  workflows only validate the scripts and docs. The GSI itself is
  downloaded by you, from the community sources, with
  [scripts/fetch-gsi.sh](scripts/fetch-gsi.sh).

## Prerequisites

- Samsung Galaxy M51, model **SM-M515F** (international). No other model
  is covered.
- **Unlocked bootloader.** This wipes the phone once, trips Knox
  permanently, drops Widevine to L3, and loses Samsung Pay / Secure Folder.
- Unofficial **TWRP** for m51, `vbmeta_disabled`, `multidisabler`, and a
  Format Data. (Full flash only — the DSU trial does not need TWRP.)
- A full **stock-firmware backup** and a working Odin restore path. This is
  your way back.
- A PC with Android platform-tools (`adb`, `fastboot`), ~10 GB free disk,
  and the GSI itself (~3–4 GB).

## Quick start

1. **Check the phone first:** `bash scripts/verify-device.sh` — it reports
   go / no-go for the prerequisites over adb.
2. **Trial boot (do this first):** follow [docs/dsu-trial.md](docs/dsu-trial.md).
3. **Full flash:** download the GSI with
   `bash scripts/fetch-gsi.sh` (HyperOS 2 by default), then follow
   [docs/install.md](docs/install.md).
4. **Report what happened** — boot, SIM/calls, fingerprint, camera — in
   [docs/known-issues.md](docs/known-issues.md) terms, so the next person
   knows what to expect.

## Known issues (expected — none confirmed on m51 yet)

From HyperOS GSI reports on *other* Samsung models (S10, A21s, A54, A71):

| Issue | Status on m51 |
|---|---|
| Camera app not installed | Expected — use GCam as a workaround |
| SIM / RIL not working for some | Expected — biggest daily-driver risk |
| VoLTE / VoWiFi | Expected broken |
| Setup wizard dead | Expected — finish setup over adb |
| Brightness bug, flashlight, status-bar glitches, gesture nav partly broken | Expected |
| Side fingerprint sensor | Unknown |
| Play Integrity / banking apps | Expected to fail (unlocked bootloader + GSI) |

Full list with sources and workarounds:
[docs/known-issues.md](docs/known-issues.md).

## Repo layout

```text
m51-hyperos/
├── README.md                  # this file
├── CREDITS.md                 # everyone whose work this builds on
├── LICENSE                    # GPL-3.0
├── docs/
│   ├── install.md             # full flash guide (TWRP + fastbootd)
│   ├── dsu-trial.md           # DSU Sideloader trial boot (do this first)
│   ├── known-issues.md        # expected broken things + workarounds
│   └── faq.md                 # questions everyone asks
├── scripts/
│   ├── fetch-gsi.sh           # download a HyperOS GSI (HyperOS 2 default)
│   └── verify-device.sh       # go / no-go prerequisite check over adb
└── .github/workflows/
    ├── validate.yml           # shellcheck + docs-link checks on push
    └── test.yml               # dry-runs the scripts (no downloads)
```

## Credits

See [CREDITS.md](CREDITS.md). HyperOS itself is Xiaomi's work; this
project redistributes none of it — you download the GSI from the
community sources listed there.

## License

GPL-3.0 — see [LICENSE](LICENSE). The scripts and docs in this repo are
free software; the HyperOS system images are Xiaomi's proprietary
firmware repackaged by the community, and their own terms apply.
