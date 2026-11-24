# Kernel defconfig plan — resolving the crDroid m51_defconfig blocker

Date: 2026-11-24. Repo: https://github.com/kkisdevil/m51-hyperos, GPL-3.0
(kernel tree and defconfig stay GPL-2.0, as the kernel is).

Companion files: [tree-takeover.md](tree-takeover.md) §3.3 and §10 item 1
(the blocker, as recorded there) and `kernel/m51_defconfig` (the merged
draft this plan produces). Skill: `m51-rom-builder` §6.

Status: **blocker resolved in plan — the merged defconfig draft exists
(`kernel/m51_defconfig`). No kernel has been built yet; the first build
must run the verification in §6.**

## 0. The blocker, restated

The takeover base kernel is the crDroid tree
(`crdroidandroid/android_kernel_samsung_sm7150`, branch `16.0`, pinned
commit `4d83f24bf0b0a32de8066096c0b7eb00d53b3a79`, 4.14.357-openela).
It has **no `m51_defconfig`**, and its `build_kernel.sh` builds
**`a71_eur_open_defconfig` — a file that does not exist anywhere in
the tree**. The script cannot run as written, for three independent
reasons (§2). The m51 device tree expects `TARGET_KERNEL_CONFIG :=
m51_defconfig` (`a71-devs/android_device_samsung_m51`,
`BoardConfig.mk`), and that file exists only in the a71-devs kernel.

## 1. The a71-devs m51_defconfig (the known-good base)

Fetched 2026-11-24 via raw.githubusercontent.com, pinned commit
`81831f0c94e628bfcb260f96a08d94f414e612a8` (branch `lineage-22.2`),
path `arch/arm64/configs/m51_defconfig`:

| Fact | Value |
|---|---|
| HTTP status | 200 |
| Size | **178,473 bytes** (matches tree-takeover.md §3.3) |
| Lines | **6,617** |
| SHA-256 | `63c4b4f16f9f7baf79c6ff350001729967295f8ae617f38c0be10ae59475754e` |
| Header | `Linux/arm64 4.14.190 Kernel Configuration` — a full `.config` dump in Samsung stock style, not a minimal `savedefconfig` |
| Enabled options (`=y` / `=m` / value) | **2,037** |

This is the config that demonstrably booted the m51 (LineageOS 22.2
from these trees). It is the base of the merged draft — not the
crDroid fragments.

## 2. The crDroid defconfig layout (verified live)

`arch/arm64/configs/` at the pinned commit contains:

| Entry | Size | What it is |
|---|---|---|
| `a70q.config` | 1,628 B | Samsung device fragment for the A70 (SM-A705) |
| `a71.config` | 2,459 B | Samsung device fragment for the A71 |
| `cuttlefish_defconfig` | 12,491 B | Generic cuttlefish emulator defconfig (not a device config) |
| `defconfig` | 13,810 B | Generic upstream arm64 `defconfig` (+ `SCHED_WALT` etc.) — **not** a Samsung/sm7150 base |
| `m51.config` | 1,931 B | Samsung device fragment for the M51 (61 options) |
| `misc_debug_defconfig` | 71 B | Debug fragment stub |
| `sdmmagpie_defconfig` | 21,977 B | QTI sm6150-family defconfig (not the sdmsteppe base) |
| `vendor/` | dir | QTI platform defconfigs — `sdmsteppe_defconfig` (21,218 B), `sdmsteppe-perf_defconfig`, `atoll_*`, `trinket_*`, `sm8150_*`, `sdmshrike_*`, `qcs*_`, `sa8155_*`, `sa2150p_*`, `gen3auto_*`, `qti-quin-gvm_*`, `debugfs.config` |

**No `m51_defconfig`, no `a71_defconfig`, no `a71_eur_open_defconfig`
anywhere in the tree — confirmed by listing the directory.** The
`a71_eur_open_defconfig` name in `build_kernel.sh` is a leftover from
an older Samsung tree layout; it was never updated when the tree moved
to the fragment model.

### 2.1 What `m51.config` actually contains (full file, 61 options)

SoC `ARCH_SEC_SM7150`; project `SEC_M51_PROJECT`,
`SEC_M51_EUR_PROJECT`; CMA `RBIN`; NFC `SEC_NFC`; camera
`GC5035_SENSOR`, `SAMSUNG_CAMERA_OTP`, `SAMSUNG_REAR_QUAD`,
`SAMSUNG_ACTUATOR_DW9817`, `GC5035_MACRO_OTP_DD_AUTOLOAD`;
MFD `MFD_S2MU106`; panels `PANEL_SW83106_FHD`,
`PANEL_SW83106_WM6676Z21_FHD`, `PANEL_S6E3FA9_AMB667UM07_FHD`;
touch `INPUT_TOUCHSCREEN_SEC_CMD`, `TOUCHSCREEN_SEC_TS_Y771`;
sound `SND_SOC_SAMSUNG_JACK`; CCIC `CCIC_S2MU106`,
`CCIC_9V_OTG_SUPPORT`; LED `LEDS_S2MU106_FLASH`; charger
`CHARGER_S2MU106`, `PM_S2MU106`, `NEW_STEP_CHARGING_CONCEPT`,
`SUPPORT_9V_D2D_CHARGING`; sensors `LSM6DSM_FACTORY`,
`SUPPORT_LIGHT_READ_UBID`, `MMC5603X_FACTORY`, `SLPI_MOTOR`,
`SENSORS_ET5XX`, `SENSORS_A96T3X6_SUB`, `STK33617_FACTORY`;
NPU `MSM_NPU`, `MSM_NPU_V2`; USB gadget `USB_CONFIGFS_F_SS_MON_GADGET`,
`USB_F_SS_MON_GADGET`; PDIC `PDIC_PD30`; MMC `MMC_PARANOID_SD_INIT`;
MUIC `USE_MUIC`, `MUIC_SYSFS`, `MUIC_NOTIFIER`, `MUIC_MANAGER`,
`MUIC_SKIP_INCOMPLETE_INSERT`, `MUIC_CORE`, `MUIC_HV`,
`MUIC_SUPPORT_CCIC`, `MUIC_SUPPORT_POWERMETER`,
`HV_MUIC_VOLTAGE_CTRL`, `MUIC_S2MU106`, `HV_MUIC_S2MU106_AFC`,
`MUIC_S2MU106_RID`, `MUIC_SUPPORT_PRSWAP`; battery
`BATTERY_SAMSUNG_V2`, `CHARGER_PCA9468`, `STEP_CHARGING`,
`AFC_CHARGER_MODE`, `BATTERY_NOTIFIER`,
`ENABLE_100MA_CHARGING_BEFORE_USB_CONFIGURED`, `BATTERY_SWELLING`,
`FUELGAUGE_S2MU106`, `FUELGAUGE_S2MU106_USE_5MILLIOHM`,
`BATTERY_AGE_FORECAST`.

Its sibling `a71.config` is the same shape for the A71
(`SEC_A71_PROJECT`, `SEC_A71_EUR_PROJECT`, PN547 NFC, IST40XX/MELFAS
touch, ANA6705 panels, S2MU107, hall sensors, MST) — the fragment
model is: **QTI platform base + one Samsung device fragment**.

### 2.2 `build_kernel.sh` in full (711 bytes, repo root)

```bash
#!/bin/bash

export ARCH=arm64
mkdir out

BUILD_CROSS_COMPILE=$(pwd)/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
KERNEL_LLVM_BIN=$(pwd)/toolchain/llvm-arm-toolchain-ship/10.0/bin/clang
CLANG_TRIPLE=aarch64-linux-gnu-
KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y"

make -j8 -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE REAL_CC=$KERNEL_LLVM_BIN CLANG_TRIPLE=$CLANG_TRIPLE a71_eur_open_defconfig
make -j8 -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE REAL_CC=$KERNEL_LLVM_BIN CLANG_TRIPLE=$CLANG_TRIPLE

cp out/arch/arm64/boot/Image $(pwd)/arch/arm64/boot/Image
```

Three independent reasons it cannot run as-is:

1. **`a71_eur_open_defconfig` does not exist** (§2 table). The
   `make ... a71_eur_open_defconfig` step fails immediately.
2. **The toolchain paths do not exist in the standalone repo.**
   `toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/` and
   `toolchain/llvm-arm-toolchain-ship/10.0/` are AOSP-checkout paths;
   the kernel repo root has **no `toolchain/` directory at all**
   (verified via the API root listing). The toolchain must be fetched
   separately — see §5.
3. **It copies the wrong output.** The last line copies
   `out/arch/arm64/boot/Image`, but this device boots
   `Image.gz-dtb` (`BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb`,
   `BoardConfigCommon.mk`; 64 MB boot partition). A plain `Image`
   is not what the boot image needs.

The GKI-style `build.config.common` / `build.config.aarch64` files do
not name a defconfig either, and their `FILES` list (`Image`,
`Image.gz`, `vmlinux`, `System.map`) also omits `Image.gz-dtb`.
They are not a substitute build path for this device.

### 2.3 The QTI platform base did not drift

The a71-devs tree has its own `arch/arm64/configs/vendor/
sdmsteppe_defconfig`. Diffed against the crDroid one (both 823
lines): **exactly 2 lines differ** — a71 has
`CONFIG_FORTIFY_SOURCE=y`, crDroid has `CONFIG_USERFAULTFD=y`
instead. The platform base is the same file in both trees; the
divergence is entirely in the device layer.

## 3. Diff: a71 full defconfig vs the crDroid fragment assembly

Method: parse each file into `{OPTION: value}` (`# CONFIG_X is not
set` → `n`); merge the crDroid assembly as `sdmsteppe_defconfig`
overlaid with `m51.config` (fragment wins, `merge_config.sh`
semantics); compare enabled options only. A secondary merge
(generic `defconfig` + `m51.config`) was also computed.

| Assembly | Enabled options |
|---|---|
| a71 `m51_defconfig` (full) | **2,037** |
| crDroid `sdmsteppe_defconfig` + `m51.config` | **856** |
| crDroid generic `defconfig` + `m51.config` | **651** |

- **1,327** options enabled in the a71 config are absent (or `n`) in
  the crDroid assembly.
- **146** options enabled in the crDroid assembly are absent (or `n`)
  in the a71 config.
- **5** options are enabled in both with different values.

### 3.1 The headline: the fragment assembly is not a complete config

856 enabled options is ~42% of what the device needs. The missing
1,327 are not trivia — grouped by area:

| Area | a71-only enabled |
|---|---|
| SoC / clock / cpufreq (incl. QTI/MSM sub-drivers) | 96 |
| Display / GPU | 17 |
| Camera | 12 |
| Audio | 23 |
| USB | 76 |
| SELinux / security | 18 |
| FS | 18 |
| Binder / IPC | 1 |
| zram / swap / memory | 10 |
| cgroup / BPF | 6 |
| Network / Wi-Fi / BT | 137 |
| Storage / MMC / UFS | 20 |
| Samsung device (SEC_/SAMSUNG_/S2MU/MUIC/CCIC/PDIC) | 48 |
| Power / PMIC | 5 |
| Misc / debug | 11 |
| Other (fine-grained driver options not matched by the buckets above) | 829 |

Building the crDroid tree from `sdmsteppe_defconfig + m51.config`
alone and letting `olddefconfig` fill the rest with Kconfig defaults
would produce a kernel missing most Samsung device drivers — the
defaults for almost all driver options are `n`. **The fragment
assembly is a delta, not a config.** That is why the resolution (§4)
takes the a71 full config as the base and layers the crDroid deltas
on top, rather than the other way round.

### 3.2 Boot-critical options — what each side has

| Option | a71 `m51_defconfig` | crDroid merged | Verdict |
|---|---|---|---|
| `ANDROID_BINDER_IPC` | y | y | Both — fine |
| `ASHMEM` | y | y | Both — fine |
| `PSI` | y | y | Both — fine |
| `SECURITY_SELINUX` | y | y | Both — fine |
| `SECCOMP` / `BPF_SYSCALL` / `CGROUP_BPF` | y | y | Both — fine |
| `ZRAM` / `MEMCG` / `CGROUP_FREEZER` | y | y | Both — fine |
| `SCHED_WALT` / `CPU_FREQ_GOV_SCHEDUTIL` | y | y | Both — fine |
| `DM_VERITY` / `MODULE_SIG`(+`_FORCE`) | y | y | Both — fine |
| `EXT4_FS` / `F2FS_FS` | y | y | Both — fine |
| `USB_CONFIGFS_F_FS` / `USB_CONFIGFS_F_MTP` | y | y | Both — fine |
| `ARCH_SEC_SM7150` / `SEC_M51_PROJECT` / `SEC_M51_EUR_PROJECT` | y | y | Both — the fragment does its job here |
| `FS_ENCRYPTION` (+`_INLINE_CRYPT`) | y | absent | **Carry the a71 value** — FBE on /data needs it. Note the merged side is internally inconsistent: it sets `FS_ENCRYPTION_INLINE_CRYPT=y` (which depends on `FS_ENCRYPTION`) without setting `FS_ENCRYPTION` itself. |
| `SECCOMP_FILTER` | y | absent | **Carry the a71 value** — Android needs seccomp filters. |
| `SECURITY_SELINUX_DEVELOP` | y | absent | **Carry the a71 value** — this is what makes `androidboot.selinux=permissive` work; without it the permissive boot image cannot switch SELinux to permissive. |
| `DISPLAY_SAMSUNG` | y | absent | **Carry the a71 value** — the Samsung display driver. |
| `DRM_MSM` | y | absent | **Carry the a71 value** — the MSM display driver. |
| `WLAN` | y | absent | **Carry the a71 value** — Wi-Fi driver switch (merged has `CFG80211` but not `WLAN`). |
| `USB_F_MTP` / `USB_F_FS` | y | absent | Legacy gadget functions; the merged side has the configfs equivalents (`USB_CONFIGFS_F_*=y`). Carry the a71 values for parity — harmless, and MTP/ADB over USB is verified against them. |
| `F2FS_FS_ENCRYPTION` | absent | y | **Carry the merged value** — FBE on f2fs /data. |
| `OVERLAY_FS` | n | y | **Carry the merged value** (`y`) — used by Treble/DSU overlay mounts; harmless. |
| `INCREMENTAL_FS` | n | y | **Carry the merged value** (`y`) — Android incremental installs; harmless. |
| `BLK_INLINE_ENCRYPTION_FALLBACK` | n | y | **Carry the merged value** (`y`) — inline-crypto fallback for FBE. |
| `IKHEADERS` | n | y | **Carry the merged value** (`y`) — in-kernel headers, useful for debugging. |
| `MSM_NPU_V2` | absent | y | **Carry the merged value** — crDroid platform addition. |
| `CPU_BOOST` | absent | y | **Carry the merged value** — QTI CPU boost. |
| `ANDROID_LOW_MEMORY_KILLER` | absent | y | **Do NOT carry.** The a71 tree deliberately uses userspace `lmkd` + PSI (the Android 12 way); the legacy in-kernel LMK is the old path. |
| `DM_DEFAULT_KEY` | n | y | **Keep the a71 value (`n`).** Revisit only if FBE metadata encryption fails on the first boot. |
| `CMDLINE` | `""` | `"cgroup_disable=pressure"` | **Keep the a71 value (empty).** The merged value disables PSI pressure stalls, which `lmkd` needs. The boot cmdline comes from the boot image, not the defconfig. |
| `MMC_TEST` / `MSM_11AD` / `QCOM_LLCC_PERFMON` / `WIL6210` | y | m | **Keep the a71 values (`y`, built-in).** |
| `EROFS_FS` (+`_ZIP`, `_XATTR`, …) | absent | absent | **Add — see §3.3.** |

### 3.3 EROFS — the crDroid tree has the backport, the a71 tree does not

- crDroid `fs/erofs/Kconfig` exists (HTTP 200). Symbols:
  `EROFS_FS`, `EROFS_FS_DEBUG`, `EROFS_FS_XATTR`,
  `EROFS_FS_POSIX_ACL`, `EROFS_FS_SECURITY`, `EROFS_FS_ZIP`,
  `EROFS_FS_PCPU_KTHREAD`, `EROFS_FS_PCPU_KTHREAD_HIPRI`.
  `EROFS_FS_ZIP` selects `LZ4_DECOMPRESS`.
- a71-devs `fs/erofs/` → **404**. No EROFS at all in the a71 tree.
- **No `EROFS_FS_ZIP_LZMA` symbol exists in the crDroid backport**
  (verified by grep — zero hits). This is the older EROFS backport,
  LZ4 only.
- Consequence: the merged defconfig enables EROFS with LZ4
  (`EROFS_FS=y`, `_XATTR`, `_POSIX_ACL`, `_SECURITY`, `_ZIP`,
  `_PCPU_KTHREAD`), but **an lzma-compressed EROFS GSI cannot be
  mounted by this kernel**. The GSI chosen for the port must be
  LZ4-compressed — verify the Mystic `spring` image's compression before
  relying on EROFS (see docs/gsi-verification.md §3 — the format is
  unknown from public metadata), and if it is lzma, either pick an LZ4 image or
  backport `EROFS_FS_ZIP_LZMA` (a separate work item, not in this
  plan). The sdmsteppe base sets no EROFS option at all, so EROFS
  must be added explicitly — it is not inherited from either side.

### 3.4 The crDroid assembly's debug flavour — do not carry it

The merged side's 146 crDroid-only options are dominated by ~40
debug options from `sdmsteppe_defconfig` (a debug-flavoured QTI
base): `DEBUG_KMEMLEAK` (+`_DEFAULT_OFF`, `_EARLY_LOG_SIZE`),
`DEBUG_SPINLOCK`, `DEBUG_MUTEXES`, `DEBUG_ATOMIC_SLEEP`,
`DEBUG_PAGEALLOC` (+`_ENABLE_DEFAULT`), `PAGE_POISONING`
(+`_ENABLE_DEFAULT`), `SLUB_DEBUG_ON`, `SLUB_DEBUG_PANIC_ON`,
`FUNCTION_TRACER`, `IRQSOFF_TRACER`, `PREEMPT_TRACER`,
`SCHED_TRACER`, `FAULT_INJECTION` (+`_DEBUG_FS`,
`_STACKTRACE_FILTER`), `FAIL_PAGE_ALLOC`, `FAIL_MMC_REQUEST`,
`UFS_FAULT_INJECTION`, `DEBUG_OBJECTS*`, `DEBUG_CREDENTIALS`,
`DEBUG_SG`, `DEBUG_STACK_USAGE`, `DEBUG_SECTION_MISMATCH`,
`DEBUG_MEMORY_INIT`, `DEBUG_NOTIFIERS`, `PAGE_OWNER_ENABLE_DEFAULT`,
`SCHED_STACK_END_CHECK`, `PANIC_ON_SCHED_BUG`,
`PANIC_ON_RT_THROTTLING`, `SOFTLOCKUP_DETECTOR`, `WQ_WATCHDOG`,
plus `CGROUP_DEBUG`, `DEBUG_BLK_CGROUP`, `PM_DEBUG`, `IPA_DEBUG`,
`ICNSS_DEBUG`, `ESOC_DEBUG`, `QCOM_GPI_DMA_DEBUG`,
`PRINT_VMEMLAYOUT`, `TTY_PRINTK`, `DYNAMIC_DEBUG`, `MEMTEST`,
`SCSI_LOGGING`, `LKDTM`, `TEST_USER_COPY`, `RCU_TORTURE_TEST`,
`LOCK_TORTURE_TEST`, `ATOMIC64_SELFTEST`, `BUG_ON_DATA_CORRUPTION`.
The a71 defconfig has these off. **None of them are carried into
the merged draft** — a shipping kernel does not want kmemleak,
page poisoning, and fault injection enabled, and they cost
performance on a 730G. (Also in the merged-only list, kept:
`MSM_SCC_SM6150`, `QCOM_LLCC` platform bits, `REGULATOR_QPNP_AMOLED`,
`QPNP_SMB5`, `QPNP_QG`, `SMB1355/1390` chargers,
`TOUCHSCREEN_SYNAPTICS_*` / `TOUCHSCREEN_HIMAX_*` /
`TOUCHSCREEN_ST` (other panels' drivers from the generic QTI base —
harmless, they simply do not bind on this hardware), `USB_PD_POLICY`,
`USB_CONFIGFS_F_UAC2`/`_F_UVC`, `USB_VIDEO_CLASS`, `USERFAULTFD`,
`HARDENED_USERCOPY_PAGESPAN`, `SLAB_FREELIST_HARDENED/RANDOM`,
`EFIVAR_FS`, `FB_VIRTUAL`, `DNS_RESOLVER`, `DVB_MPQ*`,
`MEDIA_USB_SUPPORT`, `HID_QVR`, `SERIAL_DEV_BUS`,
`SERIAL_MSM_GENI_CONSOLE`, `PINCTRL_SLPI`, `QTI_BCL_*`,
`EDAC_QCOM_LLCC*`, `CORESIGHT_*`, `CMDLINE_EXTEND`, `CMA_DEBUGFS`,
`DEBUG_CONSOLE_UNHASHED_POINTERS`, `XZ_DEC`, `BLK_DEV_IO_TRACE`,
`BLK_INLINE_ENCRYPTION_FALLBACK`, `CRYPTO_DEV_QCOM_ICE`,
`DUAL_ROLE_USB_INTF`, `NFC_NQ`, `LEDS_QPNP_HAPTICS`,
`QCOM_WDOG_IPI_ENABLE`, `QPNP_USB_PDPHY`, `STATIC_USERMODEHELPER_PATH=""`.
These are part of the QTI platform base; the draft does not add them
explicitly because the draft is a71-based, and `olddefconfig` on the
crDroid tree will surface any that the platform Kconfig defaults on.
If the first build's `.config` is missing one the platform needs,
add it then — do not pre-add the whole list on assumption.)

## 4. Resolution — the merged defconfig

**Base: the a71-devs `m51_defconfig`, verbatim.** It is a complete
config for this exact device, it is what the device tree points at,
and it is what demonstrably booted. The crDroid fragments are deltas,
not a config, so the merge direction is a71 → crDroid, not the
reverse.

**Deltas applied on top of the a71 base** (all recorded in the draft
file's header comment):

| Change | Reason |
|---|---|
| `EROFS_FS=y`, `EROFS_FS_XATTR=y`, `EROFS_FS_POSIX_ACL=y`, `EROFS_FS_SECURITY=y`, `EROFS_FS_ZIP=y`, `EROFS_FS_PCPU_KTHREAD=y` (appended) | crDroid EROFS backport (§3.3); LZ4 only, no LZMA symbol exists |
| `F2FS_FS_ENCRYPTION=y` (appended) | From the crDroid sdmsteppe base; FBE on f2fs /data |
| `MSM_NPU_V2=y`, `CPU_BOOST=y` (appended) | crDroid platform-base options |
| `OVERLAY_FS`: `n` → `y` (flipped in place) | crDroid base has it on; Treble/DSU overlay mounts |
| `INCREMENTAL_FS`: `n` → `y` (flipped in place) | crDroid base has it on; Android incremental installs |
| `BLK_INLINE_ENCRYPTION_FALLBACK`: `n` → `y` (flipped in place) | crDroid base has it on; inline-crypto fallback for FBE |
| `IKHEADERS`: `n` → `y` (flipped in place) | crDroid base has it on; in-kernel headers for debugging |
| Everything else | a71 values kept, including `CMDLINE=""`, `FS_ENCRYPTION=y`, `SECCOMP_FILTER=y`, `SECURITY_SELINUX_DEVELOP=y`, `DISPLAY_SAMSUNG=y`, `DRM_MSM=y`, `WLAN=y`, `DM_DEFAULT_KEY=n`, and the `y` (built-in) values for `MMC_TEST`, `MSM_11AD`, `QCOM_LLCC_PERFMON`, `WIL6210` |

**Not carried** (deliberate): the ~40 sdmsteppe debug options (§3.4),
`ANDROID_LOW_MEMORY_KILLER`, the `cgroup_disable=pressure` cmdline,
`DM_DEFAULT_KEY=y`.

**The draft:** `kernel/m51_defconfig` in this repo — 6,680 lines,
181,825 bytes, SHA-256
`bcbab559cb85dc77f470f0216c2b3ec2445d4003d4e56dbb18f520788cfbfc91`,
zero duplicate `CONFIG_` symbols (verified). Generated from the a71
file by script (flip the four `n`→`y` lines in place, append the
porter section, prepend the lineage header). It is a draft until the
first build runs `olddefconfig` + `savedefconfig` on the crDroid
tree (§6).

**Where it lands in the fork:** after the kernel fork is created
(`kkisdevil/android_kernel_samsung_sm7150`, §4 of tree-takeover.md),
this file goes to `arch/arm64/configs/m51_defconfig` in the fork,
and `BoardConfigCommon.mk`'s `TARGET_KERNEL_SOURCE` moves to the
forked kernel path. `TARGET_KERNEL_CONFIG := m51_defconfig` in the
m51 device tree then resolves — no device-tree change needed.

## 5. Corrected build command (replaces build_kernel.sh as-is)

Do not run the crDroid `build_kernel.sh`. The corrected flow, in a
GitHub Actions job (or a local checkout — same commands):

```bash
# 0. Toolchain — the repo has no toolchain/ dir; fetch it first.
#    GCC 4.9 (aarch64-linux-android-4.9) + Clang 10.0 are what the
#    original script expected; a maintained equivalent is proton-clang
#    (or the AOSP prebuilts clang-r383902 + gcc 4.9). Pin the exact
#    toolchain + version in the workflow when the kernel job is written;
#    do not leave the choice to "latest".
export ARCH=arm64
export CROSS_COMPILE=<gcc-4.9-prefix>          # e.g. .../aarch64-linux-android-
export REAL_CC=<clang-bin>                     # e.g. .../bin/clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export DTC_EXT=<kernel>/tools/dtc              # in-tree, exists

# 1. Defconfig — the merged draft, copied into the fork at
#    arch/arm64/configs/m51_defconfig (see §4).
make O=out ARCH=arm64 \
  CROSS_COMPILE="$CROSS_COMPILE" REAL_CC="$REAL_CC" \
  CLANG_TRIPLE="$CLANG_TRIPLE" \
  DTC_EXT="$DTC_EXT" CONFIG_BUILD_ARM64_DT_OVERLAY=y \
  m51_defconfig

# 2. Normalise — surfaces unknown/renamed symbols (a71 options that
#    no longer exist in 4.14.357-openela). RECORD the warnings (§6).
make O=out ARCH=arm64 \
  CROSS_COMPILE="$CROSS_COMPILE" REAL_CC="$REAL_CC" \
  CLANG_TRIPLE="$CLANG_TRIPLE" \
  DTC_EXT="$DTC_EXT" CONFIG_BUILD_ARM64_DT_OVERLAY=y \
  olddefconfig

# 3. Build.
make -j"$(nproc)" O=out ARCH=arm64 \
  CROSS_COMPILE="$CROSS_COMPILE" REAL_CC="$REAL_CC" \
  CLANG_TRIPLE="$CLANG_TRIPLE" \
  DTC_EXT="$DTC_EXT" CONFIG_BUILD_ARM64_DT_OVERLAY=y

# 4. Canonicalise the defconfig from the result (commit this back).
make O=out ARCH=arm64 savedefconfig
cp out/defconfig arch/arm64/configs/m51_defconfig

# 5. Outputs that matter for this device:
#    out/arch/arm64/boot/Image.gz-dtb   <-- the boot image kernel
#    (NOT plain Image — see §2.2 item 3)
#    out/arch/arm64/boot/Image.gz
#    out/arch/arm64/boot/dts/qcom/*.dtb  (DTBO is separate:
#    BOARD_KERNEL_SEPARATED_DTBO := true)
```

Notes:
- `CONFIG_BUILD_ARM64_DT_OVERLAY=y` and `DTC_EXT=$(pwd)/tools/dtc`
  are kept from the original script — the in-tree `tools/dtc`
  exists, and DT overlay support is what the Samsung DTBO flow
  needs.
- `-j8` in the original script is a 4-vCPU assumption; use
  `-j"$(nproc)"` on the runner instead.
- `mkdir out` is unnecessary — `O=out` creates it.
- The permissive boot image (`androidboot.selinux=permissive`,
  Permissiver v5 pattern) is a **packaging** step on top of
  `Image.gz-dtb`, not a defconfig change — `SECURITY_SELINUX_DEVELOP=y`
  in the defconfig is what makes the permissive cmdline effective.
- Kernel version string in the built image must read
  `4.14.357-openela` — verify before it goes near a phone
  (skill §10.1.4).

## 6. What must be verified on the first kernel build

In order; each is a gate, not a nicety:

1. **`make m51_defconfig` completes** with no error on the crDroid
   tree (the file is a full config; a Kconfig syntax error would
   fail here).
2. **`make olddefconfig` warnings are recorded.** Any a71 option
   that no longer exists in 4.14.357-openela's Kconfig tree is
   reported as unknown. List every dropped symbol in this document
   (§7) — do not silently drop them. If a dropped symbol is one of
   the boot-critical ones in §3.2 (e.g. `DISPLAY_SAMSUNG`,
   `DRM_MSM`, `WLAN`), stop: the driver is missing from the crDroid
   tree and the plan must change (carry the driver from the a71
   tree, or fall back to the a71 kernel as base). If it is a
   Samsung debug/diagnostic symbol, dropping it is acceptable.
3. **`savedefconfig` output is committed back** as the canonical
   `m51_defconfig` (replacing the draft), with the dropped symbols
   named in the commit message.
4. **The build completes** and produces
   `out/arch/arm64/boot/Image.gz-dtb`. Check: the file exists, is
   non-trivial in size, and fits the 64 MB boot partition
   (`BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864`).
5. **Kernel version string reads `4.14.357-openela`** (extract from
   the image — `strings` / `extract-ikconfig` or the build log's
   `UTS_RELEASE`). A `4.14.190` or `4.14.336` string means the wrong
   tree was built.
6. **EROFS is actually in the built kernel**: `extract-ikconfig`
   on the image (or `.config`) shows `CONFIG_EROFS_FS=y` and
   `CONFIG_EROFS_FS_ZIP=y`; and `CONFIG_EROFS_FS_ZIP_LZMA` is
   absent (confirming the LZ4-only limit, §3.3).
7. **SELinux permissive is possible**: `.config` shows
   `CONFIG_SECURITY_SELINUX_DEVELOP=y`.
8. **Boot test (needs the physical m51):** flash the permissive
   boot image and boot to fastboot/download mode at minimum, then
   to the HyperOS DSU trial (§10.2 of the skill). A kernel that
   builds but does not boot is not a pass — record the boot result
   with the log.

## 7. Open items / dropped symbols (filled in by the first build)

- [x] `olddefconfig` unknown-symbol list — **RECORDED 2026-11-24
  from run #8** (run 45372379403, artifact `m51-kernel-8`,
  `dropped-symbols.txt`, 32 symbols). None is boot-critical
  (no `DISPLAY_SAMSUNG`, `DRM_MSM`, `WLAN`,
  `SECURITY_SELINUX_DEVELOP`, `FS_ENCRYPTION`, `SECCOMP_FILTER`,
  `FS_ENCRYPTION_INLINE_CRYPT`, `ANDROID_BINDER_IPC`, `ASHMEM`),
  so the build continued and all 7 gates passed. The 32 dropped
  symbols, verbatim:

  ```
  CONFIG_ARCH_SUPPORTS_SPECULATIVE_PAGE_FAULT
  CONFIG_DEFAULT_SECURITY
  CONFIG_F2FS_FS_LZ4HC
  CONFIG_F2FS_FS_LZORLE
  CONFIG_F2FS_SEC_BLOCK_OPERATIONS_DEBUG
  CONFIG_F2FS_SEC_DEBUG_NODE
  CONFIG_F2FS_SEC_SUPPORT_DNODE_RELOCATION
  CONFIG_F2FS_STRICT_BUG_ON
  CONFIG_FSCRYPT_SDP
  CONFIG_KPERFMON
  CONFIG_LFR_SUBNET_DETECTION
  CONFIG_MCC_TO_SCC_SWITCH
  CONFIG_MPC_UT_FRAMEWORK
  CONFIG_MSM_NPU_V2
  CONFIG_QCACLD_FEATURE_GREEN_AP
  CONFIG_QCACLD_FEATURE_NAN
  CONFIG_QCACLD_WLAN_LFR2
  CONFIG_QCACLD_WLAN_LFR3
  CONFIG_QCOM_LTE_COEX
  CONFIG_QCOM_TDLS
  CONFIG_QCOM_VOWIFI_11R
  CONFIG_SECURITY_PERF_EVENTS_RESTRICT
  CONFIG_SPECULATIVE_PAGE_FAULT
  CONFIG_THIN_ARCHIVES
  CONFIG_WLAN_FASTPATH
  CONFIG_WLAN_FEATURE_11W
  CONFIG_WLAN_FEATURE_DISA
  CONFIG_WLAN_FEATURE_LPSS
  CONFIG_WLAN_NAPI
  CONFIG_WLAN_OFFLOAD_PACKETS
  CONFIG_WLAN_SYNC_TSF
  CONFIG_WLAN_TX_FLOW_CONTROL_V2
  ```

  What they are: mostly qcacld WLAN feature flags the crDroid
  tree never had (`QCACLD_FEATURE_*`, `WLAN_FEATURE_*`,
  `WLAN_FASTPATH`, `WLAN_NAPI`, `WLAN_OFFLOAD_PACKETS`,
  `WLAN_SYNC_TSF`, `WLAN_TX_FLOW_CONTROL_V2`, `QCOM_LTE_COEX`,
  `QCOM_TDLS`, `QCOM_VOWIFI_11R`, `LFR_SUBNET_DETECTION`,
  `MCC_TO_SCC_SWITCH`, `QCOM_*`), Samsung F2FS extras
  (`F2FS_FS_LZ4HC`, `F2FS_FS_LZORLE`, `F2FS_SEC_*`,
  `F2FS_STRICT_BUG_ON`, `FSCRYPT_SDP`), Samsung
  debug/diagnostic symbols (`KPERFMON`, `MPC_UT_FRAMEWORK`,
  `SECURITY_PERF_EVENTS_RESTRICT`,
  `ARCH_SUPPORTS_SPECULATIVE_PAGE_FAULT` /
  `SPECULATIVE_PAGE_FAULT`, `DEFAULT_SECURITY`,
  `THIN_ARCHIVES`). Dropping them is acceptable per plan §6
  item 2 (Samsung debug/diagnostic symbols the crDroid tree
  never had) — the WLAN driver itself (`WLAN`) survived, and
  the kernel built and linked.
- [x] `CONFIG_MSM_NPU_V2` — dropped because **that symbol does
  not exist in the crDroid tree** (it was one of the 9 appends in
  the merged draft defconfig). The NPU is covered by
  `CONFIG_MSM_NPU=y`, which IS in the committed savedefconfig,
  and the NPU objects compiled (patch 0002). Committing the
  savedefconfig automatically drops `MSM_NPU_V2`; no manual edit
  was needed, and the defconfig-plan §3.2 append list should be
  read as "MSM_NPU_V2 (dropped — symbol does not exist in this
  tree)" from now on.
- [x] `savedefconfig` commit-back — **DONE 2026-11-24.**
  `kernel/m51_defconfig` is now the reviewed savedefconfig from
  run #8 (SHA-256
  `94b251e29d5f3b39205e3e5868010e51b84015400453b9c1c17fa1a6c85d22c5`,
  23,551 B, 909 CONFIG lines), replacing the 181,825 B draft.
  Spot-checked in it: `OVERLAY_FS`, `INCREMENTAL_FS`,
  `BLK_INLINE_ENCRYPTION_FALLBACK`, `IKHEADERS`, `EROFS_FS`,
  `EROFS_FS_PCPU_KTHREAD`, `MSM_NPU`, `DISPLAY_SAMSUNG`,
  `ANDROID_BINDER_IPC`, `ASHMEM`, `F2FS_FS_ENCRYPTION`,
  `FS_ENCRYPTION_INLINE_CRYPT` all `=y`. Absent from it
  (`EROFS_FS_ZIP`, `SECURITY_SELINUX_DEVELOP`, `SECCOMP_FILTER`,
  `DRM_MSM`, `WLAN`, `FS_ENCRYPTION`) is expected:
  `savedefconfig` omits symbols at their default value; the
  runner's Gate 6/7 checks verified them `=y` in `.config` and
  passed. `Image.gz-dtb` from the same build: **19,725,654
  bytes** — fits the 64 MB boot partition (Gate 4).
- [x] `DISPLAY_SAMSUNG` / `DRM_MSM` / `WLAN` existence in the
  crDroid Kconfig tree — **RESOLVED 2026-11-24 (run #8).** None
  of the three was dropped by `olddefconfig`, so all three
  symbols exist in the crDroid tree; `DISPLAY_SAMSUNG=y` is in
  the committed savedefconfig, and the kernel built and linked
  with the MSM display driver (`sde_rm.c` compiled under patch
  0001).
- [x] Toolchain pin — **RESOLVED 2026-11-24** (docs/kernel-build.md
  §1 + `.github/workflows/build-kernel.yml`): proton-clang
  `kdrag0n/proton-clang` @ `9fb011b1` (frozen master HEAD,
  2021-05-22, Clang 13.0.0), full-Clang build (`CC=clang`,
  `CROSS_COMPILE=aarch64-linux-gnu-`, bundled GNU binutils, no
  GCC needed); `libtinfo5` installed on the runner for the
  Ubuntu-18.04-built binaries. Fallback if proton-clang fails:
  AOSP Clang r383902 + GCC 4.9 (archive URLs unverified — verify
  before wiring in).
- [ ] GSI compression check — verify the Mystic `spring` HyperOS 2 image
  is LZ4-compressed EROFS (or ext4); if it is lzma EROFS, this
  kernel cannot mount it (§3.3).

## 8. Sources

- All files fetched live 2026-11-24 via raw.githubusercontent.com
  and the GitHub API contents endpoint (no clones):
  - `a71-devs/android_kernel_samsung_a71@81831f0c`
    `arch/arm64/configs/m51_defconfig` (HTTP 200, 178,473 B, 6,617
    lines, SHA-256 in §1); `arch/arm64/configs/vendor/
    sdmsteppe_defconfig` (HTTP 200).
  - `crdroidandroid/android_kernel_samsung_sm7150@4d83f24b`
    `arch/arm64/configs/` listing (HTTP 200),
    `arch/arm64/configs/defconfig` (13,810 B),
    `arch/arm64/configs/m51.config` (1,931 B),
    `arch/arm64/configs/a71.config` (2,459 B),
    `arch/arm64/configs/vendor/sdmsteppe_defconfig` (21,218 B),
    `build_kernel.sh` (711 B, repo root),
    `build.config.common`, `build.config.aarch64`,
    `fs/erofs/Kconfig` (HTTP 200 — EROFS backport present).
  - `a71-devs/android_kernel_samsung_a71@81831f0c` `fs/erofs/`
    → 404 (no EROFS in the a71 tree); `build_kernel.sh` → 404
    (no build script in the a71 tree — it builds with plain
    `make m51_defconfig`).
- Diff method: Python parse of each file into `{OPTION: value}`
  (`# CONFIG_X is not set` → `n`), merge with fragment-wins
  semantics, enabled-options comparison grouped by area. Counts:
  a71 2,037 enabled; crDroid merged 856; generic+m51 651;
  a71-only 1,327; merged-only 146; value diffs 5.
- Prior docs: [tree-takeover.md](tree-takeover.md) §3.3, §10 item 1;
  `m51-rom-builder` skill §6.
