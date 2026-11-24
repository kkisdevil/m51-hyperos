# vendor/ — everything the HyperOS port needs, in this repo

Date: 2026-11-24. This directory is the "our own build" direction made
concrete (user order 2026-11-24): take what is needed from other
projects, modify it to fit, put it in OUR repo, credit everyone.

## Rules

1. **Small things live here; big things do not.** GitHub rejects any
   single file over 100 MB, and free LFS is 1 GB storage / 1 GB
   bandwidth. The spring GSI zip (3.1 GB), the extracted system.img
   (6.2 GB) and toolchains CANNOT live in the repo — they stay
   downloads. What lives here is the pinned fetch path (tool +
   verified URL + MD5 + guide). See `FETCH-SPEC.md`.
2. **No proprietary binaries in this repo.** Xiaomi GSI contents,
   Samsung firmware, Odin — never committed. The GPL-3.0 repo holds
   our own code, scripts, templates and docs only.
3. **Every borrowed piece names its source.** Each file below has a
   header naming the project it adapts and the differences from the
   original. Nothing is copied verbatim without a compatibility pass.
4. **Nothing here overwrites recovery.** Every zip/script/flash step
   in this project must leave the user's installed TWRP recovery
   untouched (see `docs/recovery-overwriter-removal.md`).
5. **Unproven stays unproven.** A borrowed pattern that has never
   booted on m51 is labelled as such. Workflow-green ≠ boots.

## Inventory — what is vendored here

### Scripts (`scripts/`)

| File | What it is | Adapted from | License |
|---|---|---|---|
| `patch_boot.py` | Permissive boot image + ramdisk fstab patcher (stdlib only, boot header v1/v2, newc CPIO) | Arnav3078/ColorOS17-SM7150 `scripts/patch_boot.py` (pattern) | GPL-3.0 |
| `patch_fstab.py` | Vendor fstab recipe as a file tool (ICE→encryptable, strip AVB, EROFS entries, nofail) | Arnav3078/ColorOS17-SM7150 `port_coloros.sh` §3 (pattern) | GPL-3.0 |
| `vintf_precheck.py` | Framework matrices vs vendor manifest: mandatory FAIL / UNCHECKED counts (NOT official check_vintf) | Arnav3078/Hyper371-M51 `docs/VINTF.md` (method) | — (our code) |
| `verify_build.py` | Build verification record: SHA-256 per file, `unzip -t`, `fsck.erofs --xattrs`, expected-hash compare | Arnav3078/Hyper371-M51 `docs/VERIFICATION.md` (method) | — (our code) |
| `backlight_triage.sh` | Black-screen triage: panel0-backlight node, bl_power, actual_brightness, early-unblank `max*180/425` | Arnav3078/OneOS-SM7150 commit `fb7fb18` (measured fix) | Apache-2.0 |
| `secilc_check.sh` | Offline SELinux combined-policy compile check (Hyper371 method) | Arnav3078/Hyper371-M51 `docs/SELINUX.md` (method) | — (our code) |
| `auto_gen_facts.py` | Derive device facts from a stock firmware tree (build.prop, fstab, floating feature, VINTF, SIOP) | SameerAlSahab/ProjectArcadeX `scripts/main/auto_gen.sh` (pattern) | MIT |

### Sepolicy (`sepolicy/`)

| File | What it is | Adapted from | Status |
|---|---|---|---|
| `m51.cil` | Binder allows system_server → fingerprint/sensors/audio/allocator/composer + fingerprintd data-file rules | Arnav3078/ColorOS17-SM7150 `device/samsung/m51/sepolicy/m51.cil` (pattern) | **TEMPLATE** — validate against live denials in Phase 4, never ship untested |

### Props (`props/`)

| File | What it is | Adapted from | Status |
|---|---|---|---|
| `fingerprint-side.prop` | Side fingerprint mapping (`persist.vendor.fingerprint.type=side`, HIDL 2.1) | Arnav3078/ColorOS17-SM7150 `device.prop` (pattern) | Ready for L5 |
| `volte-bypass.prop` | IMS retry disable (`ims_retry=0`, avail overrides) | Arnav3078/ColorOS17-SM7150 `tweaks.prop` §6 (pattern) | **FALLBACK ONLY** — gives up VoLTE; Floss IMS is the goal |

### Pattern docs (`docs/`)

| File | What it is | Source |
|---|---|---|
| `hidl-to-aidl-swap-pattern.md` | HIDL→AIDL HAL swap (donor binary + manifest/matrix sed) | mehedihjoy0/SpiderGirl-OS (AstroROM) |
| `fcm-bump-recipe.md` | FCM 4→5 + configstore removal; **open check: vendor FCM 5 or 6?** | mehedihjoy0/SpiderGirl-OS |
| `recovery-overwriter-removal.md` | Delete `recovery-from-boot.p`, `install-recovery.sh`, `vendor_flash_recovery.rc` | Arnav3078/ColorOS17-SM7150 |
| `samsung-ims-inventory.md` | Samsung IMS staging inventory (APK + jars + 3 libs + 307-class closure) | Arnav3078/OneOS-SM7150 |
| `miui-guards.md` | miui-services.jar guard patterns + fail-closed rule + hash-checked jars | Arnav3078/OneOS-SM7150 |
| `erofs-repack.md` | EROFS repack (`mkfs.erofs --all-root --file-contexts`, LZ4HC) + super sizing | Arnav3078/ColorOS17-SM7150 |
| `anykernel-packaging.md` | AnyKernel3 kernel-zip packaging (Image + dtb + dtbo, boot only) | kurtnettle/android_kernel_samsung_sm7150 |

### Tests (`tests/`)

| File | What it is |
|---|---|
| `make_fixtures.py` | Builds synthetic fixtures (fake v2 boot image, fstab, VINTF XMLs, stock tree, fake sysfs, build output) |
| `run_vendor_tests.sh` | Runs every vendor script against the fixtures and asserts behaviour. **22 checks, all passing (2026-11-24).** |

## What is NOT vendored here (fetch at build time — see FETCH-SPEC.md)

- **Spring GSI zip** (3,122,721,686 B, MD5 `3e6337d1…`) — SourceForge
  primary, **Google Drive mirror** (`backups/m51-hyperos/`, 5 TB
  account) as the alternative. Fetched by `scripts/fetch-gsi.sh`.
- **Stock firmware M515FXXU6DXJ2** — via samloader-rs (no IMEI);
  proprietary, never in the repo.
- **Toolchains** (proton-clang `9fb011b1`, AOSP prebuilts
  `android-15.0.0_r32`) — fetched by the build workflows.
- **Device trees / kernel / vendor blobs / lights HAL** — already
  forked under kkisdevil (see `trees/manifest.json`); this repo
  holds the port, the forks hold the base.
- **DSU Sideloader, Shizuku, Permissiver v5** — small downloads,
  fetched per the guide (Permissiver v5 is the fallback; the custom
  permissive boot image from `patch_boot.py` is the primary path).
- **samfirm.js** (jesec) — TypeScript project, not a single file;
  fetch-only from its v0.2.0 release (verify the hash first).
  The vendored-samloader approach (SpiderGirl's prebuilt binary) is
  documented in `research/08c-mehedi-other-repos.md` §4 — verify any
  prebuilt binary's provenance before trusting it.

## Open checks the vendoring must NOT paper over

1. **Vendor FCM target-level: 5 or 6?** Hyper371 says 5, our Phase 0
   audit says 6. Read the real `/vendor/etc/vintf/manifest.xml`
   from stock DXE3 and DXJ2 and record which file each number came
   from. Until settled, do not quote either number as settled.
2. **AIDL vibrator vs AIDL media converter.** Hyper371 lists an AIDL
   vibrator service; our audit found the single AIDL entry to be
   `vendor.samsung.hardware.media.converter`. Same manifest read.
3. **Backlight sysfs range is 0..13510** (not "max 255") — corrected
   in `docs/reverse-engineering.md` §3 row 8 (2026-11-24). The
   Android 0–255 scale is not the sysfs range.
4. **samloader-rs DXJ2 for INS without IMEI** — open since the Mehedi
   dive. ColorOS17's CI uses it with no IMEI; if it returns DXJ2
   there, the question is answered.
5. **Hyper371 v0.1 / ColorOS17 Nov 10 builds: first boot unproven.**
   Borrow method, not claims. Workflow-green ≠ boots.
