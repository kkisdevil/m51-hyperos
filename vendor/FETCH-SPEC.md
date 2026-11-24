# FETCH-SPEC — pinned fetch spec for what cannot live in the repo

Date: 2026-11-24. GitHub rejects any single file over 100 MB and free
LFS is 1 GB storage / 1 GB bandwidth — so the big things below stay
downloads. This file pins exactly what to fetch, from where, and how
to verify it. Every entry names its size and hash (where one exists)
so a wrong or truncated download is caught before it is used.

**Rule: never commit a proprietary binary into the GPL-3.0 repo.**
Xiaomi GSI contents, Samsung firmware, Odin — downloads only.

## 1. HyperOS GSI — spring (the base, L3)

Primary source: Mystic GSI, SourceForge project `mystic-gsi-updates`.

| Field | Value |
|---|---|
| Build | `spring` — HyperOS 2 / Android 15, OS2.0.204.0.VOUMIXM |
| Source device | Redmi 15 5G / POCO M7 Plus 5G, Snapdragon 6s Gen 3 (Qualcomm) |
| File | `Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip` |
| URL | `https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip/download` |
| Size | 3,122,721,686 bytes (exact, mirror HEAD 2026-11-24) |
| MD5 (publisher, SourceForge RSS) | `3e6337d1dd850ae2d0f7d067f8dd191c` |
| SHA-256 (computed locally, no publisher SHA-256 exists) | `ed6c670ab9f7eb87dfbd713d348809a6546c130f83b8799cc9fac1b5acd1a03d` |
| Filesystem | **ext4** (verified by magic bytes, docs/gsi-verification.md §3.1) |
| Extracted system.img | 6,232,481,792 bytes |

**Drive mirror (alternative fetch source):** MIRRORED 2026-11-25 ~02:44 IST —
`backups/m51-hyperos/gsi/` (folder id `1Lki6WecamHlTwQpXPMkM1WvmhGk7fMNu`,
under `backups/m51-hyperos/` id `1Jichu0sPVFaiI9_YFh0bD4nLss9Nl7Ip`).
The first two attempts (2026-11-25 ~00:00–00:35 IST) FAILED with Google 500
`internalError` on the CLI's single multipart upload of the whole 3.1 GB
file. The fix, same as the firmware mirror: split into 1 GiB parts and
upload each part separately with `hatch_gws_cli drive +upload`, verifying
each part on Drive by size + md5Checksum. Full record:
`downloads/gsi-drive-upload.log` (also uploaded to the Drive folder).
One incident: the `files get` verification call for part02 hung >13 min;
the part was verified instead by a fresh folder listing (size + md5
match), and the driver was stopped rather than re-uploading and
duplicating the part.

| Field | Value |
|---|---|
| Drive folder | `backups/m51-hyperos/gsi/` (id `1Lki6WecamHlTwQpXPMkM1WvmhGk7fMNu`) |
| Drive file | `Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip` — 3 parts, folder total 3,122,721,686 bytes (verified by listing) |
| Part 00 | `…MysticGSI.zip.part00` — 1,073,741,824 bytes, MD5 `622d1337c71ec10457609a141a8d34b3`, id `1YRsbfrdH_C1mY5wDUim8_9x6Ju45qm3J` |
| Part 01 | `…MysticGSI.zip.part01` — 1,073,741,824 bytes, MD5 `14be358e14f0c6db82d388277c67bfd7`, id `1naHRvWLRap4cv-XlOzF2pcbP71X-dlmd` |
| Part 02 | `…MysticGSI.zip.part02` — 975,238,038 bytes, MD5 `eed4ad8ccb8250dd89cc42508f17bb51`, id `1raQLKWvJsqI4TeJwySrMQt71FWKq02qF` |
| Rejoin note | `GSI-README.txt` in the same folder (id `1Pjr_kCAPRuMAc5ZFmqNoNypEVhWM1ZsD`) |
| Upload log | `gsi-drive-upload.log` in the same folder |
| Drive link | `https://drive.google.com/drive/folders/1Lki6WecamHlTwQpXPMkM1WvmhGk7fMNu` |

Rejoin after downloading all three parts + verifying each part's MD5:

```sh
cat Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip.part?? \
  > Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip
sha256sum Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip
# expect ed6c670ab9f7eb87dfbd713d348809a6546c130f83b8799cc9fac1b5acd1a03d
md5sum Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip
# expect 3e6337d1dd850ae2d0f7d067f8dd191c
```

SourceForge stays the primary fetch source; the Drive mirror is the
fallback. Reproduce the mirror with `bash scripts/upload-gsi-drive.sh`.

Fetch with `bash scripts/fetch-gsi.sh --build spring --out-dir downloads
--extract` (verifies size + MD5, extracts system.img). Do NOT fetch
the zip into the repo — `downloads/` is gitignored.

## 2. HyperOS GSI — alternates (not the default)

| Build | File | Size | MD5 |
|---|---|---|---|
| `gold` — HyperOS 3.0.1.0 / Android 15, **MediaTek** (Redmi Note 13 5G, Dimensity 6080) — NOT the default, NOT Qualcomm | `Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip` | 3,554,104,547 | `edb87b9e088f0e1eaa5e8bf1c0ba6113` |
| `pudding` — HyperOS 3.0.50.2 / Android 16, Qualcomm (Xiaomi 17, SM8850) — research only (Track H3) | `Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip` | 3,994,747,809 | `9eb03ec3f211365aecbaa346be9516b5` |

Same SourceForge base URL as §1, with the file name substituted.
A MediaTek-source GSI ships MTK telephony/camera jars and forces the
A03 MTK RIL/ATMs shim chain — never use `gold` as the port base.

## 3. Permissiver v5 — fallback permissive boot (NOT the primary path)

The primary path is the custom permissive boot image built with
`vendor/scripts/patch_boot.py` (L1). Permissiver v5 is the fallback
/ DSU-trial path.

| Field | Value |
|---|---|
| File | `Permissiver v5.zip` |
| URL | `https://sourceforge.net/projects/sgsi137/files/Permissiver%20v5.zip/download` |
| Size | 1,251,096 bytes |
| Date | 2022-01-02 |
| MD5 | `73f68347929e484351d2ca1f72360381` |

Verified 2026-11-24 (HTTP 200, size + MD5). It is the sgsi137 file
the DroidWin guide links — not Wahyu6070's similarly-named file.
Verify the MD5 after download; a 2022 file on a mirror is exactly
the kind of thing worth hashing before flashing.

## 4. Stock firmware — M515FXXU6DXJ2 (blob refresh + restore path)

Proprietary Samsung firmware. Never in the repo. Download with
**samloader-rs v2.0.0** (see §5), model `SM-M515F`, region `INS`
(the user's region):

```
samloader download --model SM-M515F --region INS
```

- **Open check:** does samloader-rs return DXJ2 for INS without an
  IMEI? The old Python samloader's no-IMEI `checkupdate` returns a
  stale latest (DXE3 for INS while mirrors list DXJ1). Cross-check
  the returned version against a firmware mirror before downloading.
- The firmware is also the **Odin restore path** (the way back):
  AP/BL/CP/CSC flash via Odin. The Odin tool + flashing guide are
  handled by the companion UN1CA-side task (user order 2026-11-24:
  firmware + guide + working Odin saved to our GitHub/Drive) — this
  port references the same restore path; do not duplicate the
  download here.
- Blob refresh decision (2026-11-24): the frozen 913 blobs are the
  base. DXJ1 still carries security patch 2024-05-01 and changelist
  23974102 — identical to DXE3-era builds — so a refresh is likely a
  near-no-op; only the fingerprint string would change.

## 5. Firmware download tools

| Tool | Source | Notes |
|---|---|---|
| **samloader-rs v2.0.0** (primary) | `topjohnwu/samloader-rs` releases (v2.0.0) — `https://github.com/topjohnwu/samloader-rs/releases` | Rust, no IMEI needed. Adopted by Mehedi's UN1CA (Nov 24 batch) and ColorOS17's CI — third corroboration. Verify the release asset hash before trusting it. |
| **samfirm.js v0.2.0** (third route) | `jesec/samfirm.js` releases (v0.2.0) — `https://github.com/jesec/samfirm.js/releases` | TypeScript project (index.ts + utils), NOT a single .js file — fetch the release, not a raw file. Verify the hash against the release before trusting it as a download route. |
| samloader (Python, source) | `ananjaser1211/samloader` source tarball via GitHub codeload | Gone from PyPI (404, 2026-11-24). Last resort only; no-IMEI checkupdate returns a stale latest. |

## 6. Toolchains + build prebuilts (fetched by the workflows)

| Tool | Pin | Source |
|---|---|---|
| proton-clang (kernel) | commit `9fb011b183fe7e69b04b873ef6533b4b077e3c5e`, Clang 13.0.0, frozen 2021-05-22 | `kdrag0n/proton-clang` |
| AOSP prebuilts (lights HAL build) | tag `android-15.0.0_r32` | AOSP `prebuilts/clang` (provides `clang-r536225`, exactly what LineageOS 22.2 soong expects) |
| JDK 25 (Ghidra / Mercury tool only) | `openjdk-25-jdk` 25.0.5.1 | Ubuntu repos — Ghidra 12.2 rejects JDK 21 |
| erofs-utils, simg2img, lpunpack, lpmake | unpinned upstream (build from source or the UN1CA tool cache) | `sekaiacg/erofs-utils`, AOSP `external_android-tools` |

**Do NOT use:** LostPrime's toolchain (secret URL, cannot be
reproduced), ColorOS17's unpinned `toraidl/coloros_port` binaries
(no hashes), any unpinned raw-GitHub-URL binary without a hash check.

## 7. Device trees / kernel / vendor / lights HAL (already forked)

These live in their own forked repos under kkisdevil — not in this
repo, not re-fetched here. Pins: `trees/manifest.json`.

| Repo | Fork | Pin |
|---|---|---|
| `a71-devs/android_device_samsung_m51` | `kkisdevil/android_device_samsung_m51` | lineage-22.2 `55df7b4a` |
| `a71-devs/android_device_samsung_a71-common` | `kkisdevil/android_device_samsung_a71-common` | lineage-22.2 `48e5e36e` |
| `crdroidandroid/android_kernel_samsung_sm7150` | `kkisdevil/android_kernel_samsung_sm7150` | 16.0 `4d83f24b` (4.14.357-openela) |
| `a71-devs/android_vendor_samsung_m51` | `kkisdevil/android_vendor_samsung_m51` | lineage-22.2 `de409289` |
| `a71-devs/android_vendor_samsung_a71-common` | `kkisdevil/android_vendor_samsung_a71-common` | lineage-22.2 `407f21e5` |
| `LineageOS/android_hardware_samsung` | `kkisdevil/android_hardware_samsung` | lineage-22.2 `0365e8bd` + no-op light commit `e7968ab` |

## 8. Phone-side tools (DSU trial)

| Tool | Source | License |
|---|---|---|
| DSU Sideloader (VegaBobo) | F-Droid, or `https://github.com/VegaBobo/DSU-Sideloader/releases` | Apache-2.0 |
| Shizuku | Play Store | — |
| AnyKernel3 template (only if a kernel zip is ever wanted) | `osm0sis/AnyKernel3` | GPL-3.0 |

## 9. Verification checklist (every download)

1. Size matches the exact byte count in this file.
2. Hash matches (MD5 where the publisher gives one; SHA-256 where
   one is recorded locally).
3. Filesystem format checked after download for any image (EROFS
   magic `e2 e1 f5 e0` at offset 1024, ext4 `53 ef` at offset 1080)
   BEFORE the DSU trial — never assume it.
4. A download that fails (2) or (3) is deleted and re-fetched, never
   used "because it is probably fine".
