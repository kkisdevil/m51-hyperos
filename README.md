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
- The recommended first GSI is **HyperOS 2 (Android 15)** — the Mystic
  `spring` build — not HyperOS 3:
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

## Reverse-engineering status — device-specific port (phase 1 done)

The user asked for HyperOS completely reverse-engineered and rebuilt for
the m51 — not just the GSI guide above. Phase 1 (architecture + gap map)
is done; no code has been written yet and nothing has been flashed.

- **Device trees: they exist.** The m51 has a complete tree set
  (`a71-devs`: m51 device tree + `a71-common` + 4.14 kernel + 913
  proprietary blobs) that has booted Android 14, 15 and (with patches) 16.
  But the m51 repos are **frozen since 2025-04-29** — only the A71 side is
  still maintained — so the port starts from a takeover, not a living
  upstream. Freshest kernel available: crDroid's 4.14.357-openela.
  Phase 0 audit: [docs/tree-takeover.md](docs/tree-takeover.md),
  pins: [trees/manifest.json](trees/manifest.json).
- **The real problem is HIDL vs AIDL, not VNDK.** Xiaomi's own vendor is
  frozen at API 31 too. HyperOS 2 (Android 15) still tolerates the m51's
  HIDL vendor, so it is plausible as an experiment. HyperOS 3 (Android 16)
  tooling explicitly refuses HIDL-only pre-Android-13 vendors — it is a
  research project, not a port.
- **Hardest gaps:** RIL/IMS/VoLTE, camera, the side fingerprint sensor,
  SELinux + the HyperOS 3 HIDL→AIDL cliff, and display/lights/brightness.
- **Plan:** Qualcomm-source HyperOS 2 GSI (`spring`) as the base, forked a71-devs
  trees + crDroid kernel, vendor blobs re-extracted from the latest stock,
  per-device RRO overlay, A03-style smali patches, and HAL bridges
  (VNDKLite config, sensor shim, audio policy, Floss IMS per carrier).
  Full detail: [docs/reverse-engineering.md](docs/reverse-engineering.md)
  (trees, HyperOS structure, 24-row gap table) and
  [docs/port-plan.md](docs/port-plan.md) (architecture, ordered phases,
  what needs a real m51, honest limits).

### Forks — Phase 0 done 2026-11-24

The takeover base, forked under
[kkisdevil](https://github.com/kkisdevil) with upstream names kept:

| Fork | Upstream | Branch / pin |
|---|---|---|
| [android_device_samsung_m51](https://github.com/kkisdevil/android_device_samsung_m51) | a71-devs | lineage-22.2 / `55df7b4a` |
| [android_device_samsung_a71-common](https://github.com/kkisdevil/android_device_samsung_a71-common) | a71-devs | lineage-22.2 / `48e5e36e` |
| [android_kernel_samsung_sm7150](https://github.com/kkisdevil/android_kernel_samsung_sm7150) | crdroidandroid | 16.0 / `4d83f24b` (4.14.357-openela) |
| [android_vendor_samsung_m51](https://github.com/kkisdevil/android_vendor_samsung_m51) | a71-devs | lineage-22.2 / `de409289` |
| [android_vendor_samsung_a71-common](https://github.com/kkisdevil/android_vendor_samsung_a71-common) | a71-devs | lineage-22.2 / `407f21e5` |

Not forked: `a71-devs/android_kernel_samsung_a71` (superseded as the
kernel base — its `m51_defconfig` is still the reference defconfig).
One open blocker: the crDroid kernel has no `m51_defconfig` and its
build script names a config that does not exist — see
[docs/tree-takeover.md](docs/tree-takeover.md) §3.3.

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
   `bash scripts/fetch-gsi.sh` (HyperOS 2, `spring`, by default), then follow
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
│   ├── faq.md                 # questions everyone asks
│   ├── reverse-engineering.md # phase 1: trees, HyperOS structure, gap table
│   ├── port-plan.md           # phase 1: port architecture + work phases
│   └── tree-takeover.md       # phase 0: pinned trees, audit, fork plan
├── trees/
│   └── manifest.json          # machine-readable pins + fork records
├── scripts/
│   ├── fetch-gsi.sh           # download a HyperOS GSI (HyperOS 2 / spring default)
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
