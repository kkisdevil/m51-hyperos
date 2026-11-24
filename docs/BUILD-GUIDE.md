# BUILD-GUIDE — how to build the HyperOS port from this repo

Date: 2026-11-24. Status: **Phase 0 done, Phase 1 not started.**
This guide builds the HyperOS 2 (Android 15) port for the Galaxy M51
(SM-M515F) from this repo. Nothing here has booted on a phone yet —
the DSU trial (step 0) is the first thing that touches a device, and
every layer below it is verified on the desk first.

Companion docs: `docs/port-plan.md` (architecture + phases),
`docs/reverse-engineering.md` (gap table), `docs/dsu-trial.md`,
`docs/install.md`, `vendor/README.md` (inventory),
`vendor/FETCH-SPEC.md` (pinned downloads).

## 0. Prerequisites — read before anything else

- **SM-M515F only.** No other model, no other variant.
- **Unlocked bootloader.** Unlocking wipes the phone once and trips
  Knox permanently (Secure Folder, Samsung Pay, Knox attestation
  gone), Widevine falls L1→L3. Do the backup first, even for a DSU
  trial — DSU itself does not wipe anything, but the unlock that
  enables it does.
- **A full stock-firmware backup and a working Odin restore path.**
  This is the way back. Flash on a spare device first, never a daily
  driver; keep a known-good stock firmware ready to restore.
  (Odin + flashing guide: companion UN1CA-side task, user order
  2026-11-24 — same restore path, referenced here, not duplicated.)
- **TWRP installed as the recovery — NEVER overwritten.** Every
  zip/script/flash step in this project must leave recovery
  untouched. The mechanism is `vendor/docs/recovery-overwriter-removal.md`
  (delete `recovery-from-boot.p`, `install-recovery.sh`,
  `vendor_flash_recovery.rc` from the vendor image) and the flash
  checklist in §5. Arnav's UN1CA installer encodes the same rule in
  code (`rm -f "$TMP_DIR/recovery.img"`).
- **Run `scripts/verify-device.sh` first.** It reports go / no-go
  for the prerequisites over adb before any flash attempt.
- **A GitHub account** (for the Actions builds) and **~15 GB free
  disk** on the build machine (GSI 3.1 GB + extracted system 6.2 GB
  + kernel/toolchain + build output).

## 1. What is vendored vs what is fetched — and why

| Thing | Where | Why it lives there |
|---|---|---|
| Scripts, templates, props, pattern docs | `vendor/` (this repo) | Small, our own code, GPL-3.0 / Apache-2.0 / MIT-compatible. See `vendor/README.md` for the full inventory. |
| Device trees, kernel, vendor blobs, lights HAL | Forked repos under kkisdevil (pins in `trees/manifest.json`) | They are the base, not the port. This repo holds the port; the forks hold the base. |
| Spring GSI zip (3.1 GB) + system.img (6.2 GB) | Downloaded at build time (`scripts/fetch-gsi.sh`); **Drive mirror** in `backups/m51-hyperos/` as the alternative | GitHub rejects any file over 100 MB; free LFS is 1 GB. Proprietary Xiaomi firmware — never in the GPL-3.0 repo. |
| Stock firmware M515FXXU6DXJ2 | Downloaded via samloader-rs | Proprietary Samsung firmware — never in the repo. |
| Toolchains (proton-clang, AOSP prebuilts) | Fetched by the workflows | Too big for the repo; pinned by commit/tag in `vendor/FETCH-SPEC.md` §6. |
| DSU Sideloader, Shizuku, Permissiver v5 | Downloaded per the guide | Small phone-side tools; Permissiver v5 is the fallback, the custom permissive boot image is primary. |

**License note:** everything in `vendor/` is either our own code or
an adaptation with the source named in the file header. MIT and
Apache-2.0 sources are compatible with this repo's GPL-3.0; the
credit stays in the header and in `CREDITS.md`. No-license sources
(Hyper371-M51) are borrowed as *method* only, never as code.

## 2. The 6-layer build order

Build in this order. Each layer is verified before the next starts;
a failure is debugged in its own layer only.

```
L1  Kernel (crDroid 4.14.357-openela + permissive boot image)
L2  Device tree + vendor (forked a71-devs trees, frozen 913 blobs)
L3  System image (spring HyperOS 2 GSI, ext4 — verified)
L4  HAL bridge layer (VNDKLite config, libsensorndkbridge, audio,
    SehRadio flag, keymint override, Codec2 seccomp fix)
L5  m51 RRO overlay (status bar, hole-punch, brightness, AOD,
    power profile — A54 overlay as template)
L6  Xiaomi framework patches (smali — miui-services.jar, telephony,
    account, theme, camera-ATMs)
```

### L1 — Kernel

1. The kernel fork is `kkisdevil/android_kernel_samsung_sm7150`
   (crDroid 4.14.357-openela, pin `4d83f24b`).
2. Defconfig: `kernel/m51_defconfig` in this repo (the reviewed
   savedefconfig from run #8, 909 CONFIG lines) — the a71-devs
   `m51_defconfig` as base + crDroid deltas (EROFS LZ4-only,
   F2FS encryption, OVERLAY_FS, IKHEADERS). Never run the upstream
   `build_kernel.sh` as-is (broken three ways — see
   `docs/kernel-defconfig-plan.md`).
3. Porter patches live in `patches/kernel/` (0001 sde_rm, 0002 NPU
   Makefile `:=`→`+=`, 0003 self-contained `__qdf_bug`).
4. Build in GitHub Actions (`.github/workflows/build-kernel.yml`,
   8 gates — Gate 8 is the boot test, needs the phone). The output
   is `Image.gz-dtb` for the 64 MB boot partition, version string
   exactly `4.14.357-openela`.
5. Make the **permissive boot image** with
   `vendor/scripts/patch_boot.py`:
   `python3 vendor/scripts/patch_boot.py boot.img boot-permissive.img`
   (appends `androidboot.selinux=permissive`, patches the ramdisk
   fstab: ICE→encryptable, strip AVB). **Do NOT use `--erofs`** —
   spring is ext4. Verify with `--dry-run` first.
6. Verify: `unpack_bootimg` — kernel + DTB present, sizes fit 64 MB,
   no AVB signature where `TARGET_DISABLE_AVB_SIGNING=true`.

### L2 — Device tree + vendor

1. Forks are already created (see `trees/manifest.json`). The trees
   are frozen since 2025-04-29 — treat them as an unmaintained
   snapshot to be taken over, not living upstream.
2. Blob refresh: re-extract from stock M515FXXU6DXJ2 with
   `extract-files.py` (see `docs/blob-refresh.md`). Decision
   (2026-11-24): the frozen 913 blobs are the base — DXJ1 carries
   the same patch level + changelist as DXE3-era, so a refresh is
   likely a near-no-op. If a HAL ever fails on a frozen blob,
   revisit the refresh then.
3. **TWRP preservation:** delete `recovery-from-boot.p`,
   `bin/install-recovery.sh`, `etc/init/vendor_flash_recovery.rc`
   from the vendor image (`vendor/docs/recovery-overwriter-removal.md`).
   Verify with grep — zero hits for `install-recovery` /
   `recovery-from-boot`.
4. Run the **VINTF precheck** before any device test:
   `python3 vendor/scripts/vintf_precheck.py --matrix <framework matrix>
   --manifest <vendor manifest>` — mandatory FAIL must be 0.
   (Parser-based, NOT official check_vintf, NOT VTS certification.)
5. Run the **offline SELinux compile check** before any enforcing
   attempt: `bash vendor/scripts/secilc_check.sh --platform <dir>
   --vendor <dir> --mapping <30.0 mapping dir>`. A pass means the
   combined policy compiles — it does NOT mean it boots enforcing.

### L3 — System image (the GSI)

1. Fetch: `bash scripts/fetch-gsi.sh --build spring --out-dir downloads
   --extract` — verifies the exact byte count + publisher MD5
   (`3e6337d1dd850ae2d0f7d067f8dd191c`) and extracts system.img.
   Alternative source: the Drive mirror (`backups/m51-hyperos/`,
   see `vendor/FETCH-SPEC.md` §1) — verify the MD5 after any Drive
   download; the MD5 is the authority, whichever source it came from.
2. Confirm the filesystem format from the image itself (do not
   assume it): EROFS magic `e2 e1 f5 e0` at offset 1024, ext4
   `53 ef` at offset 1080. **Spring is ext4** (verified 2026-11-24)
   — no EROFS fstab entry, no custom kernel for the filesystem.
   If a future GSI is EROFS-LZMA, STOP: this kernel cannot mount it
   (no `EROFS_FS_ZIP_LZMA` symbol).
3. **DSU trial first** (see §3). Only after a DSU trial boots
   cleanly is a fastbootd full flash considered.

### L4 — HAL bridge layer

- VNDKLite-style config (`ld.config.vndk_lite.txt`, VNDK APEX ≤14
  retained) + TrebleDroid `rw-system.sh` VINTF bypass. Do not attempt
  a "vendor 35" — freeze the FCM at 6 and let the framework tolerate it.
- Reuse a71-common's `libsensorndkbridge`; ship Samsung's
  `audio_policy_configuration_sec.xml` / `audio_effects_sec.xml`.
- `ro.telephony.samsung_sehradio=false` (Fold3 lesson — otherwise
  signal bars stick at 0).
- Keep the a71-common "Override Samsung keymint entry" manifest
  override; apply the Codec2 seccomp fix.
- Sepolicy bridge: start from `vendor/sepolicy/m51.cil` (**template
  only**) and build the real policy from live denials in Phase 4.
- HIDL→AIDL swaps: see `vendor/docs/hidl-to-aidl-swap-pattern.md`.
  First swap to attempt is the vibrator (Track H3 spike). **Never
  apply the lights swap** — our lights fix is the source-built HAL.

### L5 — m51 RRO overlay

- Template: the A54 overlay (status-bar height, hole-punch, rounded
  corners, 60 Hz refresh, power profile, brightness values imported
  from stock framework-res).
- Brightness: the sysfs range is **0..13510** (not 0..255) — see
  `docs/reverse-engineering.md` §3 row 8. The nits-table conversion
  pattern is in `vendor/docs/` (OneOS backlight-curve fix).
- Fingerprint: `vendor/props/fingerprint-side.prop` (side sensor,
  HIDL 2.1 — disable Xiaomi's optical UI paths, keep the HIDL path).
- VoLTE fallback: `vendor/props/volte-bypass.prop` — **fallback
  only**, gives up VoLTE; Floss IMS per carrier is the goal.

### L6 — Xiaomi framework patches (smali)

- First-failure triage, A03-style: fix one boot blocker at a time
  in logcat order (lights NPE → RIL → SIM power-state → camera
  ATMs → account MTD). Never batch-guess fixes.
- Guard patterns: `vendor/docs/miui-guards.md` — **fail-closed:**
  every target must match exactly once, or the build stops;
  hash-checked guarded jars; neutralise, do not remove; scope every
  hook (A03 scoped AccountManager to `com.xiaomi` / UID 1000 only).
- **Headline correction:** the MiuiLightsService NPE does NOT fire
  on the spring HyperOS 2 build (Xiaomi's padding loop + null checks
  + the AOSP parent's catch already neutralise it). The notification
  LED is a silent no-op; the fix is the no-op NOTIFICATIONS light
  in the HAL (`kkisdevil/android_hardware_samsung`, commit `e7968ab`)
  + the brightness overlay. The smali null-guard is optional
  hardening only (see `docs/re-lights.md`).

## 3. DSU trial first (do this before any flash)

Full procedure: `docs/dsu-trial.md`. Short version:

1. Unlock the bootloader (wipes once, trips Knox) + backup first.
2. Install DSU Sideloader (VegaBobo, F-Droid / GitHub) + Shizuku.
3. Select the GSI (the extracted `system.img`, or the zip — if the
   app rejects the zip, extract `system.img` first).
4. Install, boot the dynamic system from the notification.
5. Test: home screen? Wi-Fi? Calls? Write down what works and what
   does not — that is the test report (`docs/known-issues.md`).
6. Getting back: reboot. That is it.

**Filesystem gate (already cleared):** spring is ext4, so the DSU
trial can proceed on the stock kernel — no EROFS fstab entry, no
custom kernel for the filesystem, no LZMA question.

If the display is black after boot, run the backlight triage
(`vendor/scripts/backlight_triage.sh`) BEFORE touching the HAL:
check the node is `panel0-backlight`, `bl_power` is unblanked, and
`actual_brightness` (not `brightness`) is non-zero. HWC-off (GPU
composition) is the known-good display fallback on this panel.

## 4. Verify each layer

| Layer | Verification (desk, before the phone) |
|---|---|
| L1 kernel | 8-gate workflow green; `Image.gz-dtb` fits 64 MB; version `4.14.357-openela`; `patch_boot.py --dry-run` shows the permissive cmdline + fstab changes |
| L2 trees/vendor | VINTF precheck 0 mandatory FAIL; recovery-overwriter grep zero hits; secilc compile passes (if enforcing is attempted) |
| L3 GSI | MD5 matches `3e6337d1…`; ext4 magic confirmed; `unzip -t` on the zip |
| L4 bridges | Each shim named in the layer doc; sepolicy template marked as template, not shipped as finished |
| L5 overlay | Overlay builds; brightness values from stock framework-res; fingerprint props point at HIDL 2.1 |
| L6 patches | Every guard matches exactly once (fail-closed); guarded jars hash-checked |

**After every build:** run `vendor/scripts/verify_build.py <build-dir>`
and keep the `VERIFICATION.md` it writes (SHA-256 per file, zip
integrity, EROFS xattr check where the tool exists). A SKIPPED check
is reported, never faked. This is the same discipline skill §10.1
demands for every build.

**On the device (Phase 1 exit criteria):** boots to the HyperOS home
screen; touch, display, Wi-Fi work; no boot-looping service in
logcat. Every test run records: GSI build, vendor version, kernel
version, what was tested, what worked, logcat excerpts for what did
not. Results go in `docs/known-issues.md`.

## 5. Flash checklist (fastbootd full flash — only after a clean DSU trial)

1. EFS + `sec_efs` raw backups verified byte-for-byte (Hyper371's
   gate — adopt verbatim). Never flash without them.
2. Firmware baseline confirmed (DXE3 or DXJ2), bootloader unlocked
   (`OEM LOCK: OFF`), custom recovery ADB works.
3. Recovery-overwriter files deleted from the vendor image (L2 §3).
4. Flash list: boot, dtbo, vbmeta, super ONLY. **No recovery flash
   anywhere.** Verify the command list before running it.
5. `vbmeta.img` with AVB flags 0x03 (verification + verity disabled).
6. Fingerprint enrolments are wiped on flash — the user must re-enrol
   after flashing (same as the UN1CA zip behaviour).
7. First boot: logcat triage in order (L6). Do not batch-guess fixes.

## 6. Honest limits — do not promise past these

- Daily driver is **not guaranteed**; HyperOS 2 on m51 is an
  experiment until Phase 3 exit criteria are met.
- **Xiaomi Camera will not work** — GCam is the camera path.
- **Widevine falls L1→L3** (480p streaming) once the bootloader is
  unlocked; no bridge exists.
- **Knox is permanently lost** on unlock. Nothing restores it.
- **No OTA updates** — manual reflash + re-apply patches.
- **HyperOS 3 may never be a daily driver** on this vendor (HIDL→AIDL
  cliff + 4.14 kernel ceiling + TrebleDroid unmaintained since June 2025).
- **Play Integrity / banking apps** will fail without extra work.
- Emergency calls (112) remain unimplemented in Floss IMS.

## 7. Open checks (do not paper over these)

1. **Vendor FCM target-level: 5 or 6?** Hyper371 says 5, our audit
   says 6. Read the real manifest from stock DXE3 and DXJ2.
2. **AIDL vibrator vs AIDL media converter.** Same manifest read.
3. **samloader-rs DXJ2 for INS without IMEI** — open since the Mehedi dive.
4. **Hyper371 v0.1 / ColorOS17 Nov 10 builds: first boot unproven.**
   Borrow method, not claims.
5. **OneOS m51 guest testing:** all 9 guests `tested: false` as of
   Nov 23. Any tester reports since?
