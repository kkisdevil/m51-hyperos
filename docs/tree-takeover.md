# Tree takeover plan — Galaxy M51 device trees for the HyperOS port

Date: 2026-11-24. Phase 0 audit step. Companion files:
[reverse-engineering.md](reverse-engineering.md) (the audit this corrects
and extends) and [port-plan.md](port-plan.md) (Phase 0 in the ordered plan).
Repo: https://github.com/kkisdevil/m51-hyperos, GPL-3.0.

Status: **trees pinned and audited (this document). No fork has been
created yet, no firmware or GSI has been downloaded, nothing has been
built or flashed.** The next action is creating the forks under
`kkisdevil` (§4) — via the browser, not from here.

## 0. What this step did, and its limits

- Cloned **one** tree locally, shallow (`--depth 1`, branch
  `lineage-22.2`): `a71-devs/android_device_samsung_m51` into
  `trees-scratch/` (audit-only scratch dir, never committed — see
  `.gitignore`). Its HEAD was verified against the GitHub API and
  matches the pin in §1.
- The `a71-common` clone failed on a directory race: two parallel
  commands ran, and the second hit the scratch dir before the first
  one's `mkdir -p` had completed (`cd: .../trees-scratch: No such
  file or directory`). It was **not retried**: the runtime flagged the
  first clone's result for execution risk (git operations inside
  cloned content can run hooks/filters), so no further clones and no
  git commands inside cloned content were run. The rest of the audit
  was completed through the GitHub API + raw file reads instead —
  every SHA, file list, and file content below was verified live
  that way. `trees-scratch/` therefore currently contains only the
  m51 device tree; the a71-common and kernel trees are **not** on disk
  here.
- The crDroid kernel was **not cloned at all** (task instruction:
  record its exact commit, do not clone the full history). Its HEAD
  commit, Makefile version, defconfig layout, and build script were
  verified through the API.
- No firmware, no GSI, no build, no flash, no upload, no server use.

## 1. Pinned commits — the takeover base

All SHAs verified live via the GitHub API on 2026-11-24. Branch is
`lineage-22.2` everywhere it exists (the frozen branch the trees were
left on — matches HyperOS 2 / Android 15).

| # | Repo | Branch | Pinned commit | Commit date (UTC) | Commit message |
|---|---|---|---|---|---|
| 1 | `a71-devs/android_device_samsung_m51` | `lineage-22.2` (default) | `55df7b4acc4d53cf0b16774f5ce27f87e719cc37` | 2025-04-29 13:34:11 | m51: Set DUMMY_SHARED_LIB to camera binaries |
| 2 | `a71-devs/android_device_samsung_a71-common` | `lineage-22.2` (default) | `48e5e36e0fa5c9ed5bd503cbe7f0ee57381765a8` | 2025-04-28 23:54:18 | a71-common: Restore original sensors.samsung HAL |
| 3 | `a71-devs/android_kernel_samsung_a71` | `lineage-22.2` (default) | `81831f0c94e628bfcb260f96a08d94f414e612a8` | 2025-04-28 14:39:58 | drm: msm: sde: Fallback to PCC for color invert |
| 4 | `a71-devs/android_vendor_samsung_m51` | `lineage-22.2` (default) | `de40928920de66ed2b5badebe89af8bff2159b54` | 2025-04-29 13:34:28 | (vendor snapshot) |
| 5 | `a71-devs/android_vendor_samsung_a71-common` | `lineage-22.2` (default) | `407f21e505d36ad2d40de2b0eb7e01f289993932` | 2025-04-28 22:31:21 | (vendor snapshot) |
| 6 | `crdroidandroid/android_kernel_samsung_sm7150` | `16.0` (default) | `4d83f24bf0b0a32de8066096c0b7eb00d53b3a79` | 2026-11-22 22:19:11 | (kernel HEAD, 4.14.357-openela) |

Kernel versions, read from each Makefile at the pin:

- a71-devs kernel: **4.14.336** (`VERSION 4, PATCHLEVEL 14, SUBLEVEL
  336`, no EXTRAVERSION).
- crDroid kernel: **4.14.357-openela** (`VERSION 4, PATCHLEVEL 14,
  SUBLEVEL 357, EXTRAVERSION -openela`). Pushed 2026-11-22 22:20:49Z
  — the freshest SM7150 kernel available, and the takeover's kernel
  base.

### Names that do NOT exist (verified 404)

- **`a71-devs/android_kernel_samsung_sm7150` → 404.** There is no
  sm7150-named kernel under a71-devs. The m51 uses the shared
  **a71 kernel** (repo #3 above). Any instruction naming an
  a71-devs sm7150 kernel is wrong; the correct repo is
  `a71-devs/android_kernel_samsung_a71`.
- **`TheMuppets/proprietary_vendor_samsung_m51` → 404.** No official
  vendor mirror for m51 (TheMuppets has a71 and a71-common only).
  This is why the blobs must be re-extracted (§5), not mirrored.

## 2. Corrections to reverse-engineering.md §1

The phase-1 audit was right in substance; the pins above correct
four numbers in it. Update reverse-engineering.md when the plan is
next revised — do not silently leave the old figures standing.

1. **"Frozen 2025-07-15" is the repo push timestamp, not the code.**
   Every surviving branch HEAD dates to **2025-04-28/29**; the m51
   `lineage-22.2` and `lineage-23.0` branches point at the *same*
   commit (`55df7b4a`); the repos have no tags. The 2025-07-15
   `pushed_at` is a push event (branch creation/re-push) with no new
   code behind it. The trees are therefore frozen at **2025-04-29 —
   ~19 months ago**, not ~16. The freeze is older than the audit
   said; nothing in the code has moved since April 2025.
2. **Blob count is 913, not 969.** At the pins, the
   proprietary-files lists hold **180** non-comment entries (m51)
   and **733** (a71-common) — **913 total**, not 186 + 783 = 969.
   (The 969 figure was probably counted from an older revision or
   with comments/section headers included. Count method used here:
   non-empty, non-`#` lines.)
3. **HIDL HAL versions are now confirmed, not inferred.** Read from
   `a71-common/manifest.xml` at the pin (§3.2): fingerprint **2.1**
   (not "2.1/2.3"), audio **6.0**, keymaster **4.0**, gatekeeper
   **1.0**, radio.config **1.1**, `vendor.samsung.hardware.radio`
   **2.2**, gnss **2.0**, nfc **1.2**, bluetooth **1.0**,
   media.omx **1.0**. The camera provider version stays **inferred**
   (see §3.2 — it is not declared in the manifest at all).
4. **The crDroid kernel swap is NOT drop-in.** The crDroid kernel
   has **no `m51_defconfig`** and its `build_kernel.sh` references
   `a71_eur_open_defconfig`, which does not exist anywhere in the
   tree. See §3.4 — the defconfig assembly must be resolved in
   Phase 0 before the kernel can be built for m51.

What the audit confirms unchanged: FCM 6 (manifest target-level 6,
kernel target-level 5); vendor base Android 12-era; SELinux
permissive on the unofficial LOS 23 build; no official TWRP tree;
the OrangeFox tree is the only live recovery tree.

## 3. Audit findings — what is actually in the trees

### 3.1 m51 device tree (24 files, cloned locally)

`device/samsung/m51` at the pin. The whole tree:

```text
Android.bp  AndroidProducts.mk  BoardConfig.mk  README.md
device.mk  extract-files.py  lineage.dependencies  lineage_m51.mk
proprietary-files.txt (180 entries)  setup-makefiles.py  vendor.prop
overlay/frameworks/base/core/res/res/{values/config.xml,
    xml/power_profile.xml}
overlay/frameworks/base/packages/{SettingsProvider/res/values/defaults.xml,
    SystemUI/res/values/dimens.xml}
rootdir/Android.bp
rootdir/vendor/etc/init/hw/init.m51.rc
rootdir/vendor/etc/{libnfc-nci.conf, libnfc-sec-vendor.conf,
    mixer_paths_idp.xml}
sepolicy/vendor/{file.te, file_contexts, hal_nfc_default.te, nfc.te}
```

Key facts read from the files:

- `BoardConfig.mk`: `TARGET_KERNEL_CONFIG := m51_defconfig`;
  `TARGET_OTA_ASSERT_DEVICE := m51`; `TARGET_BOARD_NAME :=
  SRPTD22A005`; `VENDOR_SECURITY_PATCH := 2024-05-01`;
  `TARGET_HAVE_SEC_NFC := true`; sepolicy dir is
  `sepolicy/vendor`; includes
  `vendor/samsung/m51/BoardConfigVendor.mk` (the blob side).
- `lineage_m51.mk`: `PRODUCT_MODEL := SM-M515`; build
  fingerprint `samsung/m51nsxx/qssi:12/.../M515FXXS6DXE3`
  (Android 12, DXE3 — older than the DXJ2 the blobs must be
  re-extracted from; the fingerprint must be updated when the
  blobs are refreshed).
- `vendor.prop`: `bluetooth.device.default_name=Galaxy M51`;
  fingerprint is side-mounted —
  `ro.vendor.fingerprint.type=side`,
  `ro.vendor.fingerprint.sensor_location=1080|800|350`.
- `device.mk`: inherits `device/samsung/a71-common/common.mk`;
  adds the NFC service (`android.hardware.nfc@1.2-service.samsung`),
  the m51 mixer/NFC configs, `init.m51.rc`, and the m51 overlay.
- `lineage.dependencies`: two repos — `android_device_samsung_a71-common`
  and **`android_hardware_samsung_nfc`** (target
  `hardware/samsung/nfc`). That NFC hardware repo is an extra
  dependency the fork plan must also pin (presumably
  `LineageOS/android_hardware_samsung_nfc` — **verify the org and
  pin it in Phase 0**; it is not one of the five a71-devs repos).
- `extract-files.py` / `setup-makefiles.py`: standard LineageOS
  extract-utils scripts — the blob re-extraction mechanism (§5).

### 3.2 a71-common tree (262 files, audited via API)

`device/samsung/a71-common` at the pin. Top level: `BoardConfigCommon.mk`,
`common.mk`, `manifest.xml`, `fstab.qcom` (under `init/`), `config.fs`,
props (`odm.prop`, `product.prop`, `system.prop`, `system_ext.prop`,
`vendor.prop`), `extract-files.py`, `proprietary-files.txt` (733
entries), `sort-blobs-list.py`, `fastboot-info.txt`, and dirs `audio/`
(27), `configs/` (52), `init/` (32), `libinit/` (3), `livedisplay/`
(11), `overlay/` (12), `overlay-lineage/` (7), `rro_overlays/` (6),
`sensors/` (5), `sepolicy/` (74), `shims/` (2), `touch/` (10),
`recovery/`, `releasetools/`, `include/`.

- **`manifest.xml` — the VINTF device manifest.** `target-level="6"`
  (FCM 6, confirmed), `<kernel target-level="5"/>`. **61 HAL
  entries, all HIDL/hwbinder except one AIDL**
  (`vendor.samsung.hardware.media.converter`). Full list at the
  pin: audio 6.0, audio.effect 6.0, biometrics.face 1.0,
  biometrics.fingerprint 2.1, bluetooth 1.0, gatekeeper 1.0
  (override), keymaster 4.0 (override), media.omx 1.0, nfc 1.2,
  radio.config 1.1 (override), secure_element 1.0 (override),
  tetheroffload.control 1.1, com.qualcomm.qti.ant 1.0,
  vendor.display.color 1.3, vendor.display.postproc 1.0,
  vendor.lineage.livedisplay 2.0, vendor.lineage.touch 1.0,
  vendor.nxp.nxpnfclegacy 1.0, vendor.qti.hardware.cacert 1.0,
  capabilityconfigstore 1.0, cryptfshw 1.0, dsp 1.0, factory 1.1
  (override), fm 1.0, qseecom 1.0, tui_comm 1.0, vpp 1.3,
  wifi.wifilearner 1.0, vendor.qti.power.pasrmanager 1.0
  (override), vendor.samsung.hardware.audio 1.0, bluetooth 2.0
  (override), bluetooth.a2dp 1.0, bluetooth.a2dpsink 1.0, gnss 2.0,
  radio 2.2, radio.bridge 2.0, radio.channel 2.0, thermal 1.0 —
  plus fqname-only entries (no version element): radio (×2),
  radio.deprecated, com.qualcomm.qti.dpm.api, imscmservice,
  uceservice, vendor.qti.data.factory, data.connection,
  data.latency, embmssl, mwqemadapter, radio.am, radio.ims,
  radio.internal.deviceinfo, radio.lpa, radio.qcrilhook,
  radio.qtiradio, radio.uim, radio.uim_remote_client,
  radio.uim_remote_server, vendor.qti.ims.callinfo,
  vendor.qti.imsrtpservice.
- **Not in the manifest — open check.** These services are built
  from `common.mk` but are **not declared** in the device manifest:
  camera provider, graphics composer, sensors, power
  (`android.hardware.power`), thermal (`android.hardware.thermal`),
  health, vibrator, wifi (`android.hardware.wifi`), drm, light,
  allocator, mapper. `DEVICE_MANIFEST_FILE` is only
  `$(COMMON_PATH)/manifest.xml` (BoardConfigCommon.mk:110–111) and
  no other makefile appends to it — verified by grep. Where their
  VINTF declaration comes from (vendor-side manifest fragments?
  the framework matrix side?) must be verified on the first build
  with `check_vintf` / by inspecting the assembled vendor manifest.
  **Do not assume the manifest is complete until that check passes.**
  The camera provider version therefore stays inferred (HIDL 2.6
  per reverse-engineering.md §3 row 2) — the service is
  `android.hardware.camera.provider-service_32.samsung` in
  common.mk.
- **`BoardConfigCommon.mk` key values:** `TARGET_ARCH := arm64`,
  `TARGET_ARCH_VARIANT := armv8-2a-dotprod`,
  `TARGET_BOARD_PLATFORM := sm6150` (the platform name is sm6150,
  not sm7150 — the SoC is marketed as Snapdragon 730G / SM7150),
  `TARGET_BOARD_PLATFORM_GPU := qcom-adreno618`,
  `TARGET_KERNEL_SOURCE := kernel/samsung/a71`,
  `BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb`,
  `BOARD_KERNEL_PAGESIZE := 4096`,
  `BOARD_KERNEL_SEPARATED_DTBO := true`,
  `BOARD_KERNEL_CMDLINE` includes
  `androidboot.boot_devices=soc/1d84000.ufshc
  androidboot.fstab_suffix=qcom`,
  `BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864` (64 MB),
  `BOARD_SUPER_PARTITION_SIZE := 10385096704`,
  `BOARD_SAMSUNG_DYNAMIC_PARTITIONS_SIZE := 10380902400`,
  `BOARD_USES_METADATA_PARTITION := true`,
  `TARGET_SEPOLICY_DIR := msmsteppe`,
  `BOARD_VNDK_VERSION := current`,
  `BOARD_AVB_ENABLE := true` (AVB on in the LineageOS build —
  the HyperOS port disables it with `vbmeta_disabled`, as
  install.md already says).
- **`common.mk` — the HAL package list (416 lines).** The services
  the vendor actually ships, HIDL throughout: audio 6.0-impl
  (`.sm6150`), `android.hardware.biometrics.fingerprint-service.samsung`,
  `android.hardware.camera.provider-service_32.samsung`,
  gatekeeper 1.0, graphics.composer@2.4-service + mapper 3.0/4.0,
  `android.hardware.health-service.samsung`,
  `android.hardware.keymaster@4.0-service.samsung`,
  `android.hardware.light-service.samsung`,
  `android.hardware.power-service.pixel-libperfmgr`,
  `android.hardware.sensors-service.samsung-multihal`,
  `android.hardware.vibrator-service.samsung`,
  `android.hardware.usb@1.3-service.dual_role_usb`,
  `android.hardware.wifi-service`,
  `vendor.lineage.fastcharge@1.0-service.samsung`,
  `vendor.lineage.health-service.default`,
  `vendor.lineage.livedisplay@2.0-service.samsung-qcom.sm6150`,
  `vendor.lineage.touch@1.0-service.sm6150`, plus
  `libsensorndkbridge` (the sensor shim — `shims/libsensorndkbridge/`,
  reuse it, do not rewrite it).
- **`init/fstab.qcom`:** system ext4 **and** f2fs entries, vendor
  ext4, system_ext/product/odm ext4, /data f2fs with
  `fileencryption=aes-256-xts:aes-256-cts:v2`, zram 2 GB
  (`zramsize=2147483648`). **No EROFS entry anywhere.** If the
  chosen GSI is erofs, EROFS support must be *added* — kernel
  `CONFIG_EROFS_FS_ZIP_LZMA` (for lzma GSIs) plus an fstab entry —
  it is not present in the tree today.
- **`sepolicy/`:** 74 files — `private/` (1), `public/` (4),
  `vendor/` (69, incl. `hal_camera_default.te`,
  `hal_fingerprint_default.te`, `rild.te`, `sehradiomanager.te`,
  `sensors.te`, `tee.te`, `vendor_thermal-engine.te`,
  `vold.te`). The m51 tree adds its 4 `sepolicy/vendor` files
  (NFC). Permissive first; the enforcing merge is Phase 4 work.
- **Configs that matter for the port:** `configs/audio/` incl.
  `audio_effects_sec.xml` + `audio_policy_configuration.xml`
  (Samsung audio/Dolby — Phase 2); `configs/media/` incl.
  `media_codecs_c2_sec*.xml` + Dolby codec lists (Phase 2);
  `configs/powerhint.json`; `configs/sensors/`; `livedisplay/`
  (Samsung display features); `touch/`; `overlay/` (framework
  + SettingsProvider + SystemUI values — the L5 RRO overlay
  builds on these); `rro_overlays/` (Tethering/Wifi — the
  overlay pattern to copy).
- **Oddity — stray file:** the tree contains a file whose name
  starts with a U+200E LEFT-TO-RIGHT MARK:
  `\u200eboard-info.txt`. It is almost certainly junk (an
  editor/encoding accident), but check whether anything references
  it before deleting it in the takeover.

### 3.3 Kernel trees — the defconfig problem

- **a71-devs kernel** (`android_kernel_samsung_a71`, 4.14.336):
  has full defconfigs — `a71_defconfig` and **`m51_defconfig`**
  (178,473 bytes). This is the defconfig the m51 device tree
  expects (`TARGET_KERNEL_CONFIG := m51_defconfig`).
- **crDroid kernel** (`android_kernel_samsung_sm7150`, 4.14.357-openela):
  has **no `m51_defconfig` and no `a71_defconfig`**. What it has
  in `arch/arm64/configs/`: a base `defconfig`, Kconfig fragments
  `a71.config` / `a70q.config` / **`m51.config`** (fragment:
  `CONFIG_ARCH_SEC_SM7150=y`, `CONFIG_SEC_M51_PROJECT=y`,
  `CONFIG_SEC_M51_EUR_PROJECT=y`, `CONFIG_RBIN=y`,
  `CONFIG_SEC_NFC=y`, camera sensor + panel configs), plus
  `sdmmagpie_defconfig`, a `vendor/` dir holding QTI base
  defconfigs (`sdmsteppe_defconfig`, `sdmsteppe-perf_defconfig`,
  …), and `build.config.{common,aarch64}` (GKI-style build
  configs, which do **not** name a defconfig).
  Its `build_kernel.sh` builds **`a71_eur_open_defconfig` — a file
  that does not exist anywhere in the tree**. The script is stale
  as written and cannot build this kernel for m51 without fixing
  the defconfig step.
- **Consequence for the takeover (important):** "swap in the
  crDroid kernel" is not a file swap. Phase 0 must resolve the
  defconfig assembly first. Recommended order:
  1. Keep the a71-devs `m51_defconfig` as the known-good base
     (it is what the device tree already points at and what has
     demonstrably booted).
  2. Diff it against the crDroid assembly (`defconfig` +
     `m51.config` fragment, merged with `merge_config.sh`) and
     against the crDroid 4.14.357 source changes; carry the
     m51-specific options across.
  3. Do **not** blindly run `build_kernel.sh` — its defconfig
     target is missing. Fix the script (or the fork's build
     config) as part of the kernel takeover, and record the exact
     `make` invocation that produces a booting `Image.gz-dtb`.
  4. Verify EROFS config in the chosen defconfig (see §3.2 —
     needed only if the GSI is erofs) and the permissive boot
     image path (Permissiver v5 pattern) before any flash.

### 3.4 Vendor trees (audited via API, not cloned)

- `a71-devs/android_vendor_samsung_m51` @ `lineage-22.2`
  (`de409289`, 2025-04-29): device-specific blobs only
  (fingerprint etc.), ~71 MB, 190 files per the phase-1 audit.
- `a71-devs/android_vendor_samsung_a71-common` @ `lineage-22.2`
  (`407f21e5`, 2025-04-28): the bulk of the blobs (camera,
  audio, RIL, graphics, sensors), ~242 MB, 776 files per the
  phase-1 audit.
- Both frozen at the same April 2025 code as the device trees,
  extracted from stock Android 12 / One UI 4.1. No TheMuppets
  m51 mirror exists, so these two repos are the only blob source
  until the re-extraction in §5.

## 4. Fork plan — what gets forked under kkisdevil

Fork (not clone-and-push — keep the GitHub fork link so the
upstream stays visible and the fork point stays traceable):

| Fork (kkisdevil/…) | Upstream source | Branch | Pin (from §1) | Notes |
|---|---|---|---|---|
| `android_device_samsung_m51` | a71-devs/android_device_samsung_m51 | lineage-22.2 | `55df7b4a` | Device tree. First changes: §6. |
| `android_device_samsung_a71-common` | a71-devs/android_device_samsung_a71-common | lineage-22.2 | `48e5e36e` | Shared tree. Most HAL/config changes land here. |
| `android_kernel_samsung_sm7150` | crdroidandroid/android_kernel_samsung_sm7150 | 16.0 | `4d83f24b` | Kernel base is the **crDroid** repo, not the a71-devs kernel. Keep the upstream repo name so `TARGET_KERNEL_SOURCE` paths and references stay recognisable. |
| `android_vendor_samsung_m51` | a71-devs/android_vendor_samsung_m51 | lineage-22.2 | `de409289` | Blobs, refreshed in §5. |
| `android_vendor_samsung_a71-common` | a71-devs/android_vendor_samsung_a71-common | lineage-22.2 | `407f21e5` | Blobs, refreshed in §5. |

**Not forked:** `a71-devs/android_kernel_samsung_a71` (4.14.336) —
it is superseded by the crDroid kernel as the base. Its
`m51_defconfig` is still the reference defconfig (§3.3); copy that
file into the takeover as the starting point, with credit, rather
than forking the whole repo. The live LineageOS a71 trees
(`lineage-24.0`, Android 17) are **not** forked — they are the
cross-check upstream (§7).

Fork naming rule: keep the upstream repo names exactly. The
LineageOS build manifest (`lineage.dependencies`, roomservice)
resolves repos by name; renaming breaks the lookup for no benefit.

After forking, record the fork URLs + fork-point SHAs in
`trees/manifest.json` (update the `forks` section) and in the repo
README's tree table.

## 5. Blob situation — Android 12-era vendor, no mirror

- The frozen blob set is 913 entries (§2.2), extracted from stock
  Android 12 / One UI 4.1, last touched April 2025. Nothing in it
  is known-broken, but nothing has been re-extracted against the
  latest stock firmware either.
- **Re-extraction is owed, from stock M515FXXU6DXJ2** (latest stock,
  Oct 2024). Mechanism: the trees' own `extract-files.py`
  (standard LineageOS extract-utils — pulls from a connected device
  over adb, or from an extracted firmware directory). Steps:
  1. Download the DXJ2 stock firmware (multi-GB — **not done in
     this audit step**; it is a Phase 0 execution step, and needs
     the firmware source + a download slot).
  2. Run `extract-files.py` from the forked m51 tree against it.
  3. Diff the new blob set against the frozen 913 (list what
     changed, what was added, what disappeared). Record the diff
     in `docs/blob-refresh.md` (new file, Phase 0).
  4. Update `lineage_m51.mk`'s build fingerprint from DXE3 to the
     DXJ2 fingerprint, and `VENDOR_SECURITY_PATCH` (currently
     2024-05-01) to the DXJ2 patch level.
  5. Do **not** delete blobs that disappear from the new firmware
     without checking whether a HAL still loads them — a missing
     blob is a runtime crash, not a build error.
- **No TheMuppets mirror for m51** (404, §1) — there is no
  shortcut. The a71/a71-common TheMuppets mirrors
  (`proprietary_vendor_samsung_a71`, `..._a71-common`) cover the
  shared side only and are LineageOS-maintained; they do not
  contain the m51-specific blobs (fingerprint etc.).
- Until the re-extraction lands, the forked vendor repos stay at
  their pins. A build from the frozen blobs is acceptable for the
  first boot test (LineageOS 22.2 booted from them); the refresh
  is required before any claim that the vendor is current.

## 6. What changes in each tree for HyperOS 2

Ordered by layer (port-plan.md §1). Only the HyperOS 2 track is
listed — HyperOS 3 (HIDL→AIDL wrappers) is a separate, later track.

### m51 device tree (`device/samsung/m51`)

- `BoardConfig.mk`: keep `TARGET_KERNEL_CONFIG := m51_defconfig`
  (or change it to whatever the resolved crDroid defconfig
  assembly is called — §3.3); keep the OTA assert; AVB handling
  stays "disabled for the port" (vbmeta_disabled at flash time,
  not in the tree); `VENDOR_SECURITY_PATCH` updated on blob
  refresh (§5).
- `device.mk`: add the L5 RRO overlay package(s) and any
  HyperOS-specific init/rc additions; keep the NFC service and
  the m51 mixer/NFC configs.
- `lineage_m51.mk`: fingerprint → DXJ2 on blob refresh; a
  HyperOS product definition is a separate decision (the GSI
  route boots a prebuilt system image, so the full product build
  may never be needed — decide in Phase 1, do not pre-build it
  in Phase 0).
- `vendor.prop`: keep the side-fingerprint props (they are the
  device truth, not a HyperOS choice).
- `proprietary-files.txt` + `extract-files.py`: the blob refresh
  (§5). `sepolicy/vendor`: permissive first; new `.te` files only
  when a live denial names them (Phase 4).

### a71-common tree (`device/samsung/a71-common`)

- `manifest.xml`: **no change for HyperOS 2** — FCM stays 6, HALs
  stay HIDL. (HyperOS 3 is where this file becomes a project.)
  Resolve the §3.2 open check (undeclared camera/composer/etc.)
  first — if those HALs are declared somewhere else, record
  where; if they are genuinely undeclared, that is a finding, not
  a silent gap.
- `BoardConfigCommon.mk`: `TARGET_KERNEL_SOURCE` moves from
  `kernel/samsung/a71` to the forked kernel path when the kernel
  swap lands; `BOARD_VNDK_VERSION := current` stays; dynamic
  partition sizes stay unless the GSI layout demands otherwise.
- `common.mk`: the HAL package list is the H2 keep-list — audio
  6.0, fingerprint 2.1, camera provider (Samsung), composer 2.4,
  keymaster 4.0, sensors multihal, `libsensorndkbridge` — all
  stay. Anything dropped for HyperOS 2 gets a one-line reason in
  the commit message (e.g. Xiaomi Camera is dropped at the system
  layer, not here).
- `init/fstab.qcom`: add an EROFS entry **only if** the chosen
  GSI is erofs; otherwise leave the ext4/f2fs layout alone.
- `configs/audio/*_sec.xml`, `configs/media/*_sec*.xml`:
  Samsung audio policy/effects + Dolby codec lists — Phase 2
  work, ship the Samsung files (generic GSI policy = muffled
  speaker, no Dolby).
- `configs/powerhint.json`, `sensors/`, `shims/libsensorndkbridge`,
  `livedisplay/`, `touch/`: kept as the bridge layer's raw
  material (port/bridges/ in the m51-hyperos repo references
  these, it does not duplicate them).
- `sepolicy/{private,public,vendor}`: no change in Phase 0
  (permissive boot). Enforcing merge is Phase 4.
- Delete the stray `\u200eboard-info.txt` (U+200E in the name)
  after confirming nothing references it.

### Kernel (`kernel/samsung/sm7150`, forked from crDroid)

- Resolve the defconfig assembly (§3.3) and fix or replace
  `build_kernel.sh` (its `a71_eur_open_defconfig` target does not
  exist).
- Add EROFS support if the GSI is erofs
  (`CONFIG_EROFS_FS_ZIP_LZMA` for lzma GSIs).
- Ship as a permissive boot image (`androidboot.selinux=permissive`,
  Permissiver v5 pattern). No governor changes without a
  device-side read first (skill §6).
- Kernel version string must read `4.14.357-openela` in the built
  image — verify before it goes near a phone (skill §10.1.4).

### Vendor trees (`vendor/samsung/m51`, `vendor/samsung/a71-common`)

- Blob refresh from M515FXXU6DXJ2 (§5). Nothing else changes in
  Phase 0 — no blob is hand-edited, no HAL is replaced, no file
  is deleted on assumption.

## 7. Cross-check against live LineageOS a71

The m51 repos are an unmaintained snapshot; the A71 side lives on.
Before the first build, diff the forked trees against the live
LineageOS a71 trees and carry across the fixes that apply to m51:

- `LineageOS/android_device_samsung_a71` — `lineage-24.0`
  (Android 17, pushed 2026-08-14).
- `LineageOS/android_device_samsung_a71-common` — `lineage-24.0`
  (pushed 2026-11-16).
- `LineageOS/android_kernel_samsung_a71` — `lineage-24.0`
  (4.14.336, pushed 2026-10-06).

What to look for: HAL version bumps, sepolicy fixes, overlay
changes, and anything in the a71 tree that fixes a bug the m51
tree still has. What **not** to do: do not rebase the m51 fork
onto `lineage-24.0` — the m51 tree is Android 15-based and the
HyperOS 2 target is Android 15; cherry-pick individual fixes,
with the upstream commit named in the message.

## 8. Phase 0 exit criteria — status

| Criterion (port-plan.md §3 Phase 0) | Status 2026-11-24 |
|---|---|
| Fork the five a71-devs repos; record the fork point | **Pins recorded (§1). Forks not yet created** — next action, via browser. |
| Swap the kernel to crDroid 4.14.357-openela; verify it builds for the m51 defconfig | **Blocked on §3.3** — no `m51_defconfig` in the crDroid tree; `build_kernel.sh` references a non-existent defconfig. Defconfig assembly must be resolved before any kernel build is attempted. |
| Re-extract vendor blobs from M515FXXU6DXJ2; diff against the frozen set | **Not started** — needs the DXJ2 firmware download (multi-GB, out of scope for this audit step). |
| Cross-check against live LineageOS a71 `lineage-23.x` | **Not started** — repos identified (§7); the diff is owed. |
| Trees build (AOSP/Lineage) and boot to the existing LineageOS state; blob inventory documented; kernel version recorded | **Not started** — no build has been attempted. Blob inventory: 913 entries (§2.2). Kernel version: 4.14.357-openela (crDroid) / 4.14.336 (a71-devs). |

## 9. What Phase 0 does NOT do

- **No firmware download** (stock DXJ2, multi-GB) and **no GSI
  download** (Mystic HyperOS 2, multi-GB). Both are later Phase 0
  execution steps / Phase 1 inputs, not part of this audit.
- **No build** — no AOSP/Lineage build, no kernel build, no GSI
  assembly. The kernel cannot be built yet anyway (§3.3).
- **No flash, no DSU trial, no device work of any kind.**
- **No forks created** in this step (forking is the next action).
- **No changes to `~/workspace/un1ca-universal/`** and no use of
  any of the user's servers.
- **No upload to GitHub** in this step. The takeover doc and the
  manifest are written in the local working copy only; uploading
  them is a separate, browser-mediated step.

## 10. Open checks carried out of Phase 0

1. Defconfig assembly for the crDroid kernel (§3.3) — the one
   blocker. Resolve before any kernel build.
2. VINTF declaration for camera/composer/sensors/power/thermal/
   health/vibrator/wifi/drm/light/allocator/mapper (§3.2) —
   verify with `check_vintf` on the first build.
3. `hardware/samsung/nfc` dependency — verify the org
   (presumably LineageOS) and pin it.
4. Stray `\u200eboard-info.txt` — confirm unreferenced, then
   delete.
5. LineageOS a71 cross-check diff (§7).
6. Blob re-extraction from M515FXXU6DXJ2 (§5) — needs the
   firmware download.
7. Reverse-engineering.md §1 figures — update the frozen date
   (2025-04-29, not 2025-07-15) and the blob count (913, not
   969) when that file is next revised.

## 11. Sources

- All SHAs, dates, file lists, and file contents in §1–§3 were
  verified live via the GitHub API + raw file reads on 2026-11-24
  (branch endpoints, contents endpoints, recursive tree endpoint
  for a71-common, raw.githubusercontent for manifest.xml,
  BoardConfigCommon.mk, common.mk, fstab.qcom, Makefiles,
  defconfig fragments, build_kernel.sh).
- Local clone: `trees-scratch/android_device_samsung_m51`
  (depth 1, `lineage-22.2`, HEAD `55df7b4a` — matches the API).
- Prior audit: [reverse-engineering.md](reverse-engineering.md)
  §1 (corrected in §2 above).
- Upstream repos: a71-devs (device, common, kernel, vendor),
  crdroidandroid/android_kernel_samsung_sm7150, LineageOS a71
  trees (cross-check only).
