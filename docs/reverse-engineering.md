# Reverse-engineering HyperOS for the Galaxy M51 — phase 1

Date: 2026-11-24. Scope: architecture + gap map for a **device-specific**
HyperOS port to the Samsung Galaxy M51 (SM-M515F, Snapdragon 730G / SM7150).
This is phase 1 only — no code was written, nothing was flashed, no firmware
or GSI image was downloaded. Method: public web + GitHub research only.

Companion file: [port-plan.md](port-plan.md) (how the rebuild goes together,
ordered phases, what needs a real m51).

## 0. Verdict in one paragraph

The user's belief is confirmed: **the m51 device trees exist** — a complete
set (device tree + shared `a71-common` tree + 4.14 kernel + ~969 proprietary
blobs) that has demonstrably booted Android 14, 15 and (with unpublished
patches) 16. But they are **frozen since 2025-07-15** and only the A71 side
is still maintained, so the port starts from a takeover, not a living
upstream. On the HyperOS side, the governing problem is **not** "VNDK 31 vs
35" — Xiaomi's own vendor is frozen at API 31 too. It is **HIDL vs AIDL
HALs + the FCM support span**: HyperOS 2 (Android 15) still tolerates the
m51's HIDL vendor, so it is plausible as an experiment; HyperOS 3
(Android 16) tooling explicitly refuses HIDL-only pre-Android-13 vendors,
so it is a research project, not a port. The five hardest gaps are
RIL/IMS/VoLTE, camera, the side fingerprint sensor, SELinux + the
HyperOS 3 HIDL→AIDL cliff, and display/lights/brightness.

## 1. Device trees — the audit

All dates verified live via GitHub API + repo pages on 2026-11-24.

### 1.1 Device tree — EXISTS, frozen

| Repo | Default branch | Last push | Android | Coverage |
|---|---|---|---|---|
| [a71-devs/android_device_samsung_m51](https://github.com/a71-devs/android_device_samsung_m51) | lineage-22.2 | **2025-07-15** (~16 months ago) | 15 (branches 20/21/22.0/22.1/22.2/23.0) | Device-specific only: BoardConfig, device.mk, overlays, `sepolicy/vendor`, extract-files.py, proprietary-files.txt (186 entries). Depends on a71-common. 38 commits total. |
| [a71-devs/android_device_samsung_a71-common](https://github.com/a71-devs/android_device_samsung_a71-common) | lineage-22.2 | **2025-07-15** | 15 (lineage-23.0 branch head 2025-04-28) | Shared SM7150 tree: most HALs/configs, `sepolicy/{private,public,vendor}`. There is **no** `sm7150-common` tree; it is named `a71-common`. |
| [LineageOS/android_device_samsung_a71](https://github.com/LineageOS/android_device_samsung_a71) (A71, official) | lineage-24.0 | 2026-08-14 | **17** | A71 device tree, actively maintained. |
| [LineageOS/android_device_samsung_a71-common](https://github.com/LineageOS/android_device_samsung_a71-common) (official) | lineage-24.0 | **2026-11-16** | **17** | Shared tree, actively maintained — the live upstream the m51 tree was forked from. |

- **No official LineageOS m51 tree**: `LineageOS/android_device_samsung_m51`
  → 404. **No LineageOS wiki page for m51** (`wiki.lineageos.org/devices/m51`
  → 404); the A71 wiki page exists.
- **No crDroid m51 device repo**: `crdroidandroid/android_device_samsung_m51`
  → 404. crDroid 10.2/12.5 for m51 (XDA, unofficial) was built on the
  a71-devs trees.
- False lead: `jmengelsk/android_device_samsung_m51` (pushed 2026-07-08) is
  an **empty repo (0 KB)** — not a tree.

### 1.2 Kernel source — EXISTS, stuck on 4.14 forever

| Repo | Default branch | Last push | Kernel |
|---|---|---|---|---|
| [a71-devs/android_kernel_samsung_a71](https://github.com/a71-devs/android_kernel_samsung_a71) | lineage-22.2 | **2025-07-15** | **4.14.336** on every branch (22.2 and 23.0 verified from Makefile) |
| [LineageOS/android_kernel_samsung_a71](https://github.com/LineageOS/android_kernel_samsung_a71) (official) | lineage-24.0 | 2026-10-06 | **4.14.336** (lineage-24.0 Makefile verified) — still 4.14 even on Android 17 |
| [crdroidandroid/android_kernel_samsung_sm7150](https://github.com/crdroidandroid/android_kernel_samsung_sm7150) | 16.0 | **2026-11-22 (2 days before this audit — ACTIVE)** | **4.14.357-openela**; described as "Kernel source for the Samsung a70, a71 and m51" — the freshest kernel available |
| Samsung official source | — | — | Available at opensource.samsung.com for SM-M515F (Android 12 builds, e.g. M515FXXS6DXE4); stock firmware latest is M515FXXU6DXJ2 (Oct 2024 build). The old community fork `firemax13/sm6150_m51` is **gone (404)**. |

- There is **no** `android_kernel_samsung_sm7150` or m51-named kernel in
  a71-devs/LineageOS — the m51 uses the shared **a71 kernel** (same SoC/board).
  No kernel newer than 4.14 exists for this platform anywhere.

### 1.3 Vendor tree — EXISTS, complete-ish, frozen at Android 12-era blobs

| Repo | Default branch | Last push | Contents |
|---|---|---|---|---|
| [a71-devs/android_vendor_samsung_m51](https://github.com/a71-devs/android_vendor_samsung_m51) | lineage-22.2 | **2025-07-15** | 10 commits, 190 files, ~71 MB. Device-specific blobs only (fingerprint etc.). |
| [a71-devs/android_vendor_samsung_a71-common](https://github.com/a71-devs/android_vendor_samsung_a71-common) | lineage-22.2 | **2025-07-15** | 776 files, ~242 MB. The bulk of the blobs (camera, audio, RIL, graphics, sensors). |
| TheMuppets/proprietary_vendor_samsung_a71 | lineage-23.2 | 2026-01-21 | Official LOS vendor mirror for A71. |
| TheMuppets/proprietary_vendor_samsung_a71-common | lineage-23.2 | 2026-06-27 | Official LOS vendor mirror for common. |
| TheMuppets/proprietary_vendor_samsung_m51 | — | — | **DOES NOT EXIST (404)** — no official vendor mirror for m51. |

- Combined proprietary-files lists: **186 (m51) + 783 (a71-common) = 969
  entries** — substantially complete for an AOSP build (LOS 21/22 and crDroid
  builds booted and worked from it), but blobs were extracted from **stock
  Android 12 / One UI 4.1** firmware and have not been refreshed since July
  2025. Nothing is known-broken, but nothing has been re-extracted against
  the latest stock firmware either.

### 1.4 Other m51-relevant repos

- **Sepolicy:** present — `sepolicy/vendor` in the m51 tree,
  `sepolicy/{private,public,vendor}` in a71-common. But the unofficial
  LOS 23.0 m51 build (XDA, Dec 2025) runs **SELinux permissive** — enforcing
  is not proven on the current trees.
- **Recovery/TWRP:** **no official TWRP tree**
  (`TeamWin/android_device_samsung_m51` → 404). TWRP for m51 circulates only
  as prebuilt `.tar` files on XDA. A twrpdtgen-generated tree
  (`twrpdtgen/android_device_samsung_m51`) exists but is stale (2024-01-04).
  An OrangeFox tree is active:
  [kurtnettle/android_device_samsung_m51_recovery](https://github.com/kurtnettle/android_device_samsung_m51_recovery),
  branch `ofox12_1`, pushed **2026-11-13**, status "Testing".
- **LineageOS 23.0 (Android 16) for m51 exists unofficially** (XDA thread,
  build 2025-12-25): it uses a **hybrid — newer LineageOS common tree +
  legacy a71-devs m51 tree with local, unpublished patches** (disabled UDFPS,
  disabled charging-bypass). Known bugs: SELinux permissive, fingerprint
  on-screen hint misplaced (sensor works), stock WebView unstable,
  VoLTE/VoWiFi untested. This proves the m51 tree *can* be brought to
  Android 16, but the adaptation is not committed anywhere public.
- **Other old forks:** `samsung-sm6150-devs/android_device_samsung_m51`
  (lineage-21, last push 2024-01-18, dead);
  `bekirakil-0/android_device_samsung_m51` (pushed 2025-08-27, TWRP author's
  tree); `Lehkeda/android_device_samsung_m51` (LOS 17.1, 2021, dead).

### 1.5 Tree audit verdict

**The trees are sufficient as a starting point, but not as a drop-in base —
expect real porting work.** What exists: a complete, proven set (m51 device
tree + a71-common + shared 4.14 kernel + ~969 proprietary blobs) that has
demonstrably booted Android 14, 15 and (with patches) 16. What is missing:

1. **Maintenance:** all five a71-devs m51/a71-common/kernel/vendor repos are
   frozen at 2025-07-15 (16 months); the `lineage-23.0` (Android 16) branches
   are from April 2025. Only the A71 side lives on in LineageOS/crDroid.
2. **Any HyperOS-specific tree: none exists.** A HyperOS port needs a
   new/adapted device tree, not a rebrand — HyperOS 2 maps to Android 15
   (matches the frozen `lineage-22.2` branch); HyperOS 3 ships on Android
   15 as well as Android 16 (e.g. Mystic `gold` is HyperOS 3.0.1.0 on
   Android 15) — the vendor-compat fact that matters is the Android base,
   not the HyperOS number. HyperOS 3 on Android 16 needs the
   `lineage-23.0` branch plus the unpublished local patches from the
   LOS 23 builder, or a forward-port from live LOS a71 `lineage-23.x`).
3. **Kernel ceiling: 4.14 forever** (336 in LOS, 357-openela in crDroid —
   the freshest option). Workable for HyperOS 2/3 ports, but no upstream
   security updates beyond community backports.
4. **Stale vendor blobs:** Android 12-era stock blobs, never re-extracted;
   no TheMuppets mirror for m51; re-extraction from latest stock
   (M515FXXU6DXJ2) is owed.
5. **SELinux enforcing unproven** on current trees (LOS 23 m51 runs
   permissive); **no official TWRP tree** (OrangeFox tree is the only live
   recovery tree, still "Testing").

**Recommended base:** fork `a71-devs/android_device_samsung_m51` +
`a71-common` + vendor at `lineage-22.2` (HyperOS 2 / Android 15) or
`lineage-23.0` (HyperOS 3 on Android 16), swap in
`crdroidandroid/android_kernel_samsung_sm7150` (4.14.357-openela, actively
maintained) and cross-check against the live LineageOS a71 `lineage-23.x`
trees — and treat the m51 repos as an unmaintained snapshot to be taken
over, not a living upstream.

## 2. HyperOS structure — what a HyperOS system needs from the vendor

### 2.1 Partition layout (stock Xiaomi, HyperOS 2 / 3)

| Partition | Contents | Samsung port: keep / replace |
|---|---|---|
| `system` | **Mi Shared System Image (`missi`)** — near-pure AOSP + Xiaomi framework; fingerprint e.g. `Xiaomi/missi/missi:15/AP3A.240905.015.A2/OS2.0.213.0.VOFMIXM`. One shared system across Xiaomi 15, Redmi K80 Ultra, tablets, etc. | **Replace** with the GSI (MysticGSI merges partitions into `system` by default; `--no-merge` keeps them separate) |
| `system_ext` | `miui-framework.jar`, `miui-services.jar`, `mediatek-telephony-base/common.jar` **or** Qualcomm telephony jars (depends on source device), Xiaomi service frameworks | **Replace** (comes with the GSI) |
| `product` | Xiaomi apps/overlays, `priv-app/MIUIXiaomiAccount`, ThemeManager, Security Center, Mi Camera, Mi Launcher/Home, AOD | **Replace** (comes with the GSI; non-critical for boot per obsidian kit) |
| `mi_ext` | Xiaomi overlay partition; **not self-contained** — mirrors `product/`, `system/`, `system_ext/` structure, merged at boot for regional customisation; `mi_ext/etc/build.prop` carries `ro.product.mod_device` | **Replace / drop** — GSI merges it into `system`; a Samsung has no `mi_ext` slot, so it must be merged, not flashed separately |
| `vendor`, `odm`, `vendor_dlkm`, `odm_dlkm` | Xiaomi SoC HALs, kernel modules | **KEEP SAMSUNG — never flash Xiaomi's.** This is the whole Treble contract |
| `boot`, `vendor_boot`, `dtbo`, `vbmeta` | Xiaomi kernel (GKI 5.10/5.15/6.1), vbmeta | **KEEP SAMSUNG / custom** (m51 kernel 4.14, permissive boot; vbmeta verification disabled) |
| `super` (dynamic) | `system, system_ext, product, vendor, vendor_dlkm, mi_ext, odm_dlkm` (obsidian LP metadata) | m51 is A-only + dynamic partitions; GSI guides delete `product`/`system_ext` logical partitions and flash one big `system.img` via fastbootd |

Key structural fact: **Xiaomi's own vendor is frozen at API 31** even on
HyperOS 2/Android 15 (`missi` system on a VNDK-31 vendor is "standard VNDK
freeze" — obsidian kit). HyperOS 2 therefore does *not* demand a vendor at
API 35. What it demands is a vendor inside Google's FCM support span.

### 2.2 VNDK / FCM — the governing numbers

- **FCM levels (AOSP):** 6 = Android 12, 7 = 13, 8 = 14, **202404 = 15**,
  **202504 = 16**. m51 vendor = **FCM 6**.
- **Support span:** Treble originally covered current + 3 previous FCMs; from
  202404 it is **current + 6 previous (7 total)**. FCM 6 is therefore still
  inside the span for Android 15, and is listed among the supported levels
  for Android 16 — but at the extreme edge, and only because old HIDL HALs
  are *tolerated for upgrading devices*, not required of new ones.
- **VNDK deprecated in Android 15** (AOSP VNDK docs; Celadon A15 notes): no
  VNDK APEX for 15, `ro.vndk.version` removed for 15-built vendors,
  `BOARD_VNDK_VERSION` forced empty. VNDK ≤14 APEXes survive only as legacy
  support for old vendors. So "VNDK 31 vs 35" is the wrong frame for
  HyperOS 2/3: the question is **HIDL vs AIDL HALs + FCM span**, not a VNDK
  number.
- **HyperOS 2 = Android 15, SDK 35, FCM 202404.** HyperOS 3 ships on
  Android 15 too (SDK 35, FCM 202404 — e.g. Mystic `gold`,
  `OS3.0.1.0.VNQCNXM`) and on Android 16 (SDK 36, FCM 202504, e.g.
  `OS3.0.9.0.WODCNXM`). The HyperOS number and the Android base are
  independent; the vendor-compat conclusions in this doc rest on the
  Android base, not the HyperOS number (see
  [gsi-verification.md](gsi-verification.md) §2).
- **HIDL deprecated since Android 13**, frozen not gone (~726 `.hal` files
  still in the Android 17 tree; `libhidl`/`hwservicemanager` survive as a
  compat shim). Android 15's own HAL set is ~100% AIDL for new devices
  (Celadon A15: audio core AIDL v1, audio effects AIDL v2, **camera provider
  AIDL v1**, graphics composer3 AIDL v2, thermal AIDL v2, allocator AIDL v2,
  sensor AIDL v2). An independent Android-16 GSI project states flatly:
  **"HIDL-only vendor partitions (pre-Android 13) are not supported"** —
  AIDL-only, binder-only, lazy/optional HALs. That is the HyperOS 3 cliff in
  one line.
- **Phh/TrebleDroid rule** (still the GSI bible): use a GSI whose Android API
  ≥ the device's VNDK; VNDKLite devices need VNDKLite GSIs. TrebleDroid's
  last release was an Android 16 pre-release, June 2025; its
  `device_phh_treble` carries the Samsung-specific shims (`sepolicy/samsung.te`
  is minimal — `system_server` `set_prop` on `boot_prop`;
  `BOARD_ROOT_EXTRA_FOLDERS += bt_firmware sec_storage efs` for Samsung
  layouts) plus the `vendor_hardware_overlay` RROs that fix Samsung
  brightness/AOD/status-bar/notch per device.

### 2.3 Xiaomi framework services and their vendor dependencies

| Xiaomi service / component | Where it lives | What vendor thing it expects |
|---|---|---|
| `miui-framework.jar` / `miui-services.jar` (incl. `MiuiLightsService`) | `system_ext/framework/` | A lights HAL exposing Xiaomi's notification-light object; on Samsung it NPEs at boot — A03 fix was a null-safe fallback in `miui-services.jar` |
| `com.miui.securitycenter` + `com.miui.guardprovider` + XSOF, `com.mobiletools.systemhelper` | `system/priv-app/` / `product/priv-app/` | System UID, `QUERY_ALL_PACKAGES` etc.; no HAL, but they assume Xiaomi's trust/attestation chain; degrade to "unavailable", do not block boot |
| `com.xiaomi.joyose`, `com.miui.powerkeeper` | product | Power/thermal HAL + Xiaomi `powerkeeper` hooks; misreads Samsung power HAL → wrong throttling/battery stats |
| MIUIXiaomiAccount (`com.xiaomi.account`) | `product/priv-app/MIUIXiaomiAccount/` | **`vendor.xiaomi.hardware.mtdservice`** (absent on Samsung → login stuck at "Checking password..." until patched to return immediately); Xiaomi Cloud `cloudidprovider` (fallback to Android ID); `Intent.getMiuiFlags()`, `miui.os.Build.IS_PRIVATE_WATER_MARKER`, Find Device service `com.xiaomi.finddevice` (all need null/optional-path shims; A03 T1.14.1) |
| ThemeManager + `miui.drm.DrmManager` | product | Theme rights DB/hash validation; hidden-API `ThemeNativeUtils` methods must be moved blacklist→whitelist in `miui-framework.jar` |
| HyperOS/MIUI Camera (`com.android.camera`) | product | Xiaomi camera framework JARs/native libs + Leica libs; expects Xiaomi vendor camera extensions — **not** a plain Camera2 client (see §3 row 2) |
| `com.miui.home`, `com.miui.aod`, `com.xiaomi.misettings`, `com.miui.miwallpaper` | product | Display refresh-rate / AOD low-power panel mode / lights; AOD and gestures break without Samsung overlay |
| Telephony: `MtkTeleService` / `MtkRIL` / `MtkRadioExProxy` **if the GSI source device is MediaTek**; Qualcomm-telephony jars if Snapdragon source | `system_ext/framework/mediatek-telephony-*.jar` or qcom equivalent | `vendor.mediatek.hardware.radio` / `vendor.mediatek.hardware.camera.atms.IATMs` — **absent on any Samsung**. A03 fix (T1.12–T1.14, the template for m51): disable MTK component-factory injection → generic AOSP RIL → `android.hardware.radio@1.5::IRadio/slot1`; then restore MTK factory but route only `makeRil()` to the generic RIL (hybrid), then fix the SIM power-state constant (`SIM_POWER_STATE_SIM_ON = 0x0B`, not `0x01`) or `TelecomAccountRegistry` never registers the PhoneAccount and calls fail before `RIL.dial()` |
| HyperAI / Super XiaoAi, SAIV-type AI services | system/product | No vendor HAL dependency documented in retrieved sources; depend on Xiaomi cloud + NPU/NNAPI — treat as **unknown / gracefully degraded**, not a boot blocker |
| Setup wizard (`com.android.setupwizard` MIUI variant) | system/product | **Dead on Samsung GSIs** in every report; needs to be skipped/bypassed, not fixed at the HAL layer |

### 2.4 XMAPort — what it does and does NOT do for Samsung

XMAPort (`NorthStarK-Lvy/XMAPort`) migrates a source Xiaomi device's
`system / system_ext / product / mi_ext` onto a **target Xiaomi device's
official base ROM**, keeping the target's `odm / vendor / vbmeta`, with
feature sync (refresh-rate, camera, face-unlock), APEX sync, build.prop
patching, HWC patches for Dimensity 8100/8200, erofs/ext4 repack + optional
`super.img`. It is **Xiaomi→Xiaomi only** (tested: Redmi Note 12R → K70/Note
12 Turbo/Xiaomi 12/17 Ultra, etc.; theoretical support Xiaomi 11–15 / Redmi
K50–K90). There is no Samsung base ROM for it to migrate onto, and its
`device_platform` (Qualcomm/MTK) + `device_size` (super size) model assumes
an official Xiaomi target. **For m51 the analogue is not XMAPort — it is a
GSI (system-only) + Samsung vendor + TrebleDroid-style overlays + smali
patches.** XMAPort is still useful as the reference for *which* partitions
move (system/system_ext/product/mi_ext) and *which* stay (vendor/odm/vbmeta).

### 2.5 How HyperOS handles SELinux vs the vendor

HyperOS ships Xiaomi's system sepolicy; the Samsung vendor ships Samsung's
vendor sepolicy (sepolicy version tied to FCM 6). They are not merged by
flashing — the GSI boots with the **vendor's policy + the GSI's policy
overlaid**, and every Xiaomi service that touches a Samsung-only domain
(rild, `sec_storage`, `efs`, Samsung HALs, `vendor.xiaomi.hardware.mtdservice`
lookups) generates denials. Community practice, documented in every Samsung
HyperOS guide, is to **flash a Permissiver v5 (permissive) boot image** and
run SELinux permissive; TrebleDroid adds only tiny vendor `.te` files
(samsung/qualcomm). There is no published enforcing HyperOS-on-Samsung
policy. Enforcing would require a full audit2allow merge: Xiaomi system
domains + Samsung vendor domains + new domains for every
`vendor.xiaomi.*` / `vendor.mediatek.*` service the framework probes, plus
neverallow conflicts — a bring-up project in itself, not a patch.

## 3. Gap table — interface × HyperOS requirement × m51 vendor reality

Verdicts: **works** / **needs bridge** / **needs replacement** / **unknown**.
"H2" = HyperOS 2 (Android 15), "H3" = HyperOS 3 (Android 16). A HyperOS 3
build on Android 15 (Mystic `gold`) follows the H2 column's Android-15
vendor contract, not H3. m51 baseline:
SM-M515F, SM7150/SD730G, Adreno 618, launched Android 10, last stock Android
12/One UI 4.1, kernel `4.14.190`, vendor base Android 11, A-only + dynamic
partitions, 6.7" 1080×2400 60 Hz Super AMOLED Plus, side capacitive
fingerprint, 64+12+5+5 MP rear / 32 MP front, 7000 mAh. Exact m51
vendor-manifest HAL versions were not retrievable in full text; the versions
below are the Android-12/SM7150-era values consistent with the a71-common
tree (shared with m51) and are marked **inferred — verify on-device**
(`adb shell lshal`, `/vendor/etc/vintf/manifest.xml`).

| # | Interface / service | HyperOS 2 (A15) requirement | HyperOS 3 (A16) requirement | m51 vendor reality | Verdict H2 / H3 | Bridge sketch |
|---|---|---|---|---|---|---|
| 1 | VNDK / FCM / VINTF | FCM 202404; span covers FCM 6–202404; HIDL tolerated for upgrading devices | FCM 202504; span covers FCM 6–202504 on paper, but AIDL-only GSI projects refuse HIDL-only pre-A13 vendors | FCM 6, VNDK 31, vendor API 30/31 (vendor base A11) | **needs bridge** / **needs bridge** (edge) | Ship a **VNDKLite-style GSI** (relaxed linker namespaces, `ld.config.vndk_lite.txt`, VNDK APEX ≤14 retained) + TrebleDroid `rw-system.sh` VINTF bypass; do not attempt a "vendor 35" — instead freeze the FCM at 6 and let the framework tolerate it. For H3 add the Vendor15-style frozen FCM (all HALs optional/AIDL-only) — unproven on FCM 6 |
| 2 | Camera provider | AIDL camera provider v1 preferred; HIDL 2.4–2.6 still in FCM 202404 for upgraders; Xiaomi Camera needs Xiaomi camera libs | AIDL v1+; HIDL camera effectively dropped from new FCM | HIDL `camera.provider@2.6` (inferred), Samsung proprietary camera HAL + `vendor.samsung.hardware.camera.provider` extensions, 4 rear lenses hidden behind Samsung ids | **needs bridge** / **needs replacement** | H2: keep Samsung HIDL provider, use a neutral Camera2 client (GCam/Lineage camera — A03 proved the HAL itself works, ~30 s delay was a Xiaomi ATMs lookup, fixed by making `adjCameraPriority()` return without waiting for `vendor.mediatek.hardware.camera.atms`); **drop Xiaomi Camera** (needs ANXCamera-style port with Xiaomi libs + per-lens config, no maintainer exists for m51). H3: write/adopt a **HIDL→AIDL camera-provider wrapper** (binder translation, like TrebleDroid's Bluetooth HidlToAidlMiddleware) or a new AIDL provider wrapping `camera.samsung.so` — the largest single engineering item after RIL |
| 3 | RIL / radio (`android.hardware.radio`) | HIDL radio 1.5/1.6 tolerated; AIDL radio v1+ preferred | AIDL radio | HIDL radio **1.5** (A03's Samsung/Unisoc RIL connected at 1.5; SM7150 Samsung same era), Samsung `libsec-ril.so` + `rild`, Samsung `ISehRadio` vendor extension | **needs bridge** / **needs bridge** | **Qualcomm-source GSI only** (avoid MTK telephony jars entirely). Then the A03 hybrid: keep Xiaomi telephony framework components, route only `makeRil()` to generic AOSP RIL, fix `getSimOnOffState()` → `0x0B`. Plus Fold3 lesson: set `ro.telephony.samsung_sehradio=false` or Samsung RIL stops filling the standard signal report (bars stuck at 0) |
| 4 | IMS / VoLTE / VoWiFi | AOSP IMS (`ImsService`) + carrier config | Same, stricter | **Samsung proprietary IMS** — documented as incompatible with AOSP IMS; "VoLTE will not function on GSI ROMs on Samsung hardware" (bootloader-unlock wall-of-shame, citing phh's `ims` as incomplete/unstable) | **needs replacement** / **needs replacement** | **phh Floss IMS as a privileged app**, patched per-carrier (Fold3 proved VoLTE + HD voice AMR-WB on Telstra with Floss + telephony patches + carrier IMS APN + VoIP-audio-mode call routing to fix the ~40 dB mic loss). No Indian-carrier (Jio/Airtel/Vi) Floss config exists for m51 — must be built and tested per carrier; emergency calls (112) remain unimplemented in Floss. This is the #1 daily-driver blocker |
| 5 | Fingerprint / biometrics | Biometrics AIDL v3–v5 preferred; HIDL `biometrics.fingerprint@2.1/2.3` tolerated in 202404 | AIDL biometrics v5; HIDL fingerprint dropped | **Side-mounted capacitive** sensor (power-button), HIDL fingerprint 2.1/2.3 (inferred), Samsung TEE trusted app; **not** in-display optical like A71 | **needs bridge** / **needs replacement** | H2: TrebleDroid HIDL fingerprint adapter + framework patch to re-set the active group/user on every HAL connection (Fold3 fix for enrolment loss at boot/rild restart). Xiaomi's biometric stack expects in-display/optical flows — disable face/fingerprint UI paths that probe Xiaomi sensors, keep only the HIDL path. H3: **HIDL→AIDL biometrics wrapper**; no TrebleDroid FOD fix applies (those are for under-display sensors) |
| 6 | Audio (`android.hardware.audio`) | AIDL audio core v1 / effects v2 preferred; HIDL audio 7.x tolerated | AIDL audio | HIDL **audio 7.0/7.1** + audio.effect 7.0, Samsung `audio_policy_configuration_sec.xml` / `audio_effects_sec.xml` (SoundBooster/SoundAlive/Dolby), QCOM HAL | **needs bridge** / **needs bridge** | Keep Samsung HIDL audio; ship Samsung's `*_sec.xml` policy/effects (Fold3: generic GSI policy = muffled speaker, no Dolby; Samsung files restore it + Dolby decoders AC-3/E-AC-3/AC-4 in the codec list). BT-audio: TrebleDroid HidlToAidlMiddleware `LOG(FATAL)`→`LOG(ERROR)` fix for Samsung Scalable/aptX Adaptive codecs. Call-audio routing needs the Floss/IMS VoIP-mode patch (row 4) |
| 7 | Display / graphics composer (HWC) | Composer3 AIDL v2 preferred; HIDL composer 2.4 tolerated | Composer AIDL | HIDL **graphics.composer@2.4**, mapper 4.0, Adreno 618, Samsung panel (60 Hz only — the 120 Hz GSI bug does not apply to m51) | **needs bridge** / **needs bridge** | Keep HIDL composer via TrebleDroid compat; add an **m51 vendor_hardware_overlay RRO** (status-bar height, hole-punch, rounded corners, refresh 60 Hz, power profile) — the A54 overlay is the template (merged into TrebleDroid). XMAPort's HWC patches are MediaTek-only and do not transfer |
| 8 | Lights / brightness / flashlight | AIDL lights v1–2; `MiuiLightsService` needs a lights HAL | Same | HIDL lights (Samsung), Samsung backlight sysfs range 0..13510 (Android scale 0–255), non-linear; `MiuiLightsService` NPEs on missing Xiaomi light (A03) | **needs bridge** / **needs bridge** | (i) Null-safe fallback in `miui-services.jar` (A03 T1.5, directly reusable pattern). (ii) TrebleDroid Samsung backlight fixes: "extended brightness range" + "alternative backlight scale" + Samsung `config_autoBrightnessLevels/Values` imported from stock framework-res into the overlay (a71-common already does "overlay: Import brightness values from stock"). (iii) Flashlight: works via camera HAL only when the camera app holds it (A03) — expect QS flashlight to need a lights-HAL shim |
| 9 | Power (`android.hardware.power`) + thermal | Power AIDL v2–3 + ADPF; thermal AIDL v2 | Power AIDL v3, thermal AIDL v2+ | HIDL power 1.x + `power.qti`, thermal **2.0-service.qti** (a71-common builds this), Samsung `powerkeeper` expectations absent | **needs bridge** / **needs bridge** | Keep HIDL power/thermal; stub ADPF (Adaptive Performance) — HyperOS `joyose`/`powerkeeper` will mis-throttle without it, accept degraded thermal throttling. a71-common's `thermal@2.0-service.qti` is the reusable piece; no Xiaomi `powerkeeper` port exists |
| 10 | Health / battery | Health AIDL v2–3 | Health AIDL v3 | HIDL health 2.1 / AIDL health 1 (A12-era), 7000 mAh, 25 W charging | **works** (degraded) / **needs bridge** | Mostly works; battery stats need the overlay power profile (A54 overlay precedent). Fast-charge signalling is a Xiaomi `persist.vendor.*charge` build.prop matter (XMAPort patches these per-device) — set from Samsung's values, don't copy Xiaomi's |
| 11 | Vibrator | Vibrator AIDL v1–2 | AIDL v2 | HIDL vibrator 1.x, Samsung haptic driver | **works** / **needs bridge** | H2: HIDL vibrator tolerated. H3: thin HIDL→AIDL vibrator wrapper or accept no haptics |
| 12 | Sensors (`android.hardware.sensors`) | Sensor AIDL v2 | Sensor AIDL v2+ | HIDL sensors 2.1 (accel/gyro/prox/compass/light; Samsung sensor types are non-standard) | **needs bridge** / **needs bridge** | a71-common already ships a **`libsensorndkbridge` shim** (Evolution-X commit) — reuse it. Auto-rotation/proximity in SystemUI need the Samsung sensor types mapped in the overlay; A03/A54 precedent |
| 13 | GNSS / GPS | GNSS AIDL v2 | GNSS AIDL v2+ | HIDL GNSS 2.1 (QCOM `gps.samsung`), Samsung `sec` location stack | **works** / **needs bridge** | H2: HIDL GNSS still works under TrebleDroid. H3: HIDL→AIDL GNSS wrapper |
| 14 | Wi-Fi / Bluetooth | Wi-Fi AIDL v1; BT AIDL (Hci 2.x / audio AIDL) | Same, stricter | HIDL wifi 1.5/1.6 + `vendor.qcom.hardware.wifi`, BT HIDL 1.0/1.1 + Samsung codecs; Wi-Fi 802.11ac, BT 5.0 | **works** / **needs bridge** | Wi-Fi/BT media generally work on Samsung GSIs (Fold3/A50 tables: both working). BT *calls* do not (A50: "Bluetooth calls: No"). BT audio needs the HidlToAidlMiddleware FATAL fix (row 6) |
| 15 | NFC | NFC AIDL v1; HIDL NFC 1.0/2.0 tolerated | AIDL NFC | HIDL NFC (NXP, region-dependent on m51) | **works** (degraded) / **needs bridge** | Basic NFC works; tap-to-pay will not (Play Integrity BASIC only on unlocked bootloader + no Xiaomi TEE attestation) |
| 16 | Keymaster / KeyMint, Gatekeeper | KeyMint AIDL v2–3; Gatekeeper AIDL v1 | KeyMint v3+ | HIDL **keymaster 4.0/4.1** + gatekeeper 1.0, Samsung TEE (TrustZone) + Knox (tripped on unlock) | **needs bridge** / **needs replacement** | a71-common has an explicit commit "manifest: Override Samsung keymint entry" — the override is the bridge for H2. Knox-dependent features (Secure Folder, Samsung Pay, Knox attestation) are **permanently lost** on unlock; Widevine falls L1→L3 (480p streaming) per GSI reports. H3: KeyMint AIDL wrapper around keymaster 4.x is unproven |
| 17 | DRM / Widevine, Codec2 / media | Widevine L1 + Codec2 AIDL; Samsung Codec2 seccomp | Same | Widevine L1 (stock), Samsung Codec2 HAL with a seccomp policy that kills it on GSI (`mremap`) | **needs bridge** / **needs bridge** | TrebleDroid already fixed the Codec2 seccomp kill upstream; Widevine L1 is lost on unlock (L3) — accept, no bridge exists. Dolby decoders need adding to the GSI codec list (row 6) |
| 18 | Kernel (4.14.x) | Xiaomi GKI 5.10+; HyperOS 2 system calls need binder/ashmem/eBPF present in 4.14 | GKI 6.1/6.6; more eBPF/LSM expectations | **4.14.190**, Samsung/QCOM, A-only | **needs bridge** / **needs bridge** | Not a boot blocker by itself: A03 boots HyperOS 1 on 4.14, and LineageOS 23 (Android 16) for m51 boots on 4.14.x with a hybrid tree. Needs: permissive boot image, EROFS support in kernel+fstab if the GSI is erofs (MysticGSI: lzma needs `CONFIG_EROFS_FS_ZIP_LZMA`), backported binder/ashmem ioctls where HyperOS 3's system_server probes them, and the a71 kernel source (`LineageOS/android_kernel_samsung_a71`) as the base. **No kernel backport to 5.10 exists for SM7150** — this caps how far H3 can go |
| 19 | SELinux | Enforcing with Xiaomi system + vendor policy merged | Enforcing, stricter neverallows | Samsung vendor sepolicy (FCM 6) + Knox domains; HyperOS system sepolicy expects Xiaomi domains | **needs bridge** (permissive) / **needs replacement** | **Permissive only** in practice (Permissiver v5 boot image, `androidboot.selinux=permissive`). Enforcing = a full policy-merge project: Xiaomi `miui-services`/`mtdservice`/guardprovider domains + Samsung `rild`/`sec_storage`/`efs` domains + TrebleDroid `samsung.te`/`qualcomm.te` + audit2allow from live denials. No published enforcing policy for HyperOS-on-Samsung exists |
| 20 | Xiaomi services (account, themes, security, camera app) | See §2.3 | Same | None of `vendor.xiaomi.*` / `vendor.mediatek.*` exists | **needs bridge** / **needs bridge** | Per-service smali shims, A03-style, first-failure/minimal-patch: null-safe `MiuiLightsService`; MTD-service immediate-return; CloudID→Android-ID fallback; `getMiuiFlags()`/`IS_PRIVATE_WATER_MARKER` defaults; Find Device unavailable (not fatal); ThemeManager hidden-API whitelist. **Do not** fake authentication or globally disable signature checks (A03 scoped the AccountManager hook to `com.xiaomi` / UID 1000 only) |
| 21 | Setup wizard / first boot | MIUI setup wizard | Same | Samsung setup (One UI) absent | **needs replacement** / **needs replacement** | Skip/bypass the wizard (all Samsung HyperOS reports: "SETUP IS DEAD"); provision via ADB/`settings` + a TrebleDroid-style first-boot script. Not fixable at the HAL layer |
| 22 | Status bar / SystemUI / AOD / gestures | HyperOS SystemUI + `com.miui.aod` + gesture nav | Same | Samsung SystemUI absent; Samsung low-power panel mode (HLPM) for AOD | **needs bridge** / **needs bridge** | m51 RRO overlay (A54 template: status-bar height/bottom alignment, hole-punch, rounded corners, AOD enable + burn-in shift, power profile, 25 W charging, dynamic refresh — m51 is 60 Hz so refresh items drop out). HyperSonic/AMIUI A71 bug list is the warning: gesture nav, setup-wizard buttons, Mi Launcher crashes, AOD dead, brightness weird, biometrics dead — expect the same on m51 without the overlay + framework patches |
| 23 | Storage / encryption (FBE) | FBE + metadata encryption, `vold` AIDL | Same | Samsung FBE (metadata + file-based), `sec_storage`/`efs` | **works** (with caveats) / **needs bridge** | GSI requires format-data on first flash; TrebleDroid handles Samsung FBE via `BOARD_ROOT_EXTRA_FOLDERS` + vold compat. No re-encryption to Xiaomi's scheme — keep Samsung's |
| 24 | OTA / updates | Xiaomi OTA (`com.android.updater`) | Same | Samsung OTA absent | **needs replacement** / **needs replacement** | No OTA path; updates = reflash GSI + re-apply patches (MysticGSI `rebuild` keeps layout). Accept as a manual process |

## 4. Top 5 hardest gaps

1. **RIL/IMS/VoLTE** — Samsung's proprietary IMS has no AOSP equivalent;
   Floss IMS is incomplete, per-carrier, and has no emergency-call
   implementation. (Rows 3–4)
2. **Camera** — Xiaomi Camera is not a Camera2 app; it needs Xiaomi camera
   libs + vendor extensions, while m51's HIDL 2.6 Samsung provider hides 3 of
   4 lenses and HyperOS 3 wants an AIDL provider that does not exist for this
   HAL. (Row 2)
3. **Fingerprint** — side capacitive HIDL sensor vs Xiaomi's in-display/optical
   biometric stack and AIDL Biometrics v5; enrolment loss at boot is the known
   Samsung-GSI failure mode and no FOD fix applies to a side sensor. (Row 5)
4. **SELinux + HyperOS 3 HIDL→AIDL cliff** — permissive is the only published
   state, and Android 16 GSI tooling explicitly refuses HIDL-only
   pre-Android-13 vendors; enforcing + AIDL wrappers is a bring-up project,
   not a patch set. (Rows 1, 19)
5. **Display/lights/brightness** — HIDL composer 2.4 + Samsung backlight scale
   vs Composer3 AIDL and `MiuiLightsService`, which NPE-crashes at boot on a
   missing Xiaomi light; the fix is a per-device overlay + smali patch, and the
   A71 precedent shows gestures/AOD/launcher still break after it. (Rows 7–8,
   22)

## 5. Bottom line

- **HyperOS 2 on m51 is plausible as an experiment, not a daily driver:**
  FCM 6 is inside Android 15's support span, Xiaomi's own vendor is frozen at
  API 31, the A03 precedent proves HyperOS boots on a 4.14 kernel + HIDL
  Samsung vendor with smali shims, and the Fold3 project proves a Samsung GSI
  can eventually get VoLTE + fingerprint + Dolby working — but only with
  per-device overlays, a permissive boot image, a Qualcomm-source GSI, and the
  A03 hybrid-RIL + Floss-IMS work rebuilt for Indian carriers.
- **HyperOS 3 on m51 is a research project, not a port:** it needs HIDL→AIDL
  wrappers for camera, radio, biometrics, audio, power, GNSS and KeyMint, a
  frozen/optional FCM, and kernel backports that do not exist for SM7150 —
  with no TrebleDroid release since June 2025 to build on.
- **First concrete step if pursued:** pick a **Qualcomm-source** Mystic
  HyperOS 2 GSI (`spring` — never a MediaTek-source one, e.g. Mystic
  `gold`, HyperOS 3.0.1.0 on Android 15 from a Dimensity 6080 device;
  that is what forces the MTK RIL/ATMs shims), flash it over the latest
  m51 stock vendor with a permissive boot image, and triage first-failure
  logcat exactly as the A03 project did (lights NPE → RIL → SIM
  power-state → camera ATMs → account MTD), with an m51 RRO overlay built
  from the A54 template.

## 6. Sources

- MysticGSI tool (open-sourced): https://github.com/MysticGSI/mysticgsi
- XMAPort README: https://github.com/northstark-lvy/xmaport/blob/HEAD/README_EN.md
- HyperOS-on-Samsung A03 project (framework/RIL/account/theme patches):
  https://github.com/w111user/hyperos-gsi-samsung-galaxy-a035f/blob/HEAD/README.md
- HyperOS 2 obsidian kit (`missi`, vendor frozen API 31, `mi_ext`):
  https://github.com/nt-b3st/obsidian-devtree-kit/blob/HEAD/README.md
- AOSP FCM lifecycle (levels 6/7/8/202404/202504, 7-version span):
  https://source.android.com/docs/core/architecture/vintf/fcm
- AOSP VNDK deprecation (Android 15):
  https://source.android.com/docs/core/architecture/vndk
- AOSP HAL / HIDL deprecation: https://aospbooks.github.io/aosp-internal-book/10-hal/
- Celadon Android 15 (AIDL HAL versions):
  https://projectceladon.github.io/celadon-documentation/release-notes/base-releases-A15.html
- Android 16 GSI for A15 vendors, HIDL-only refusal:
  https://github.com/zerofrip/Vendor15-GSI
- phh Treble GSI list / rule:
  https://github.com/phhusson/treble_experimentations/wiki/Generic-System-Image-%28GSI%29-list
- Fold3 Samsung GSI fixes (Floss IMS, SehRadio, fingerprint, audio, Codec2):
  https://github.com/jaso1000/Fold3-LineageOS/blob/HEAD/README.md
- Samsung IMS incompatibility / VoLTE on GSI:
  https://deepwiki.com/zenfyrdev/bootloader-unlock-wall-of-shame/2.1-samsung
- Droidwin HyperOS 2 on Samsung (bug list + Permissiver v5 + 120 Hz ADB
  workaround): https://droidwin.com/how-to-flash-hyperos-2-android-15-gsi-on-samsung/
- A71 HyperSonic/AMIUI thread (same porter team, bug list):
  https://xdaforums.com/t/rom-a15-hypersonic-rom-for-galaxy-a71.4748744/
- m51 device tree (a71-devs, lineage-22.2):
  https://github.com/a71-devs/android_device_samsung_m51
- m51 stock firmware (A12, kernel 4.14.190, vendor base A11):
  https://samfrew.com/download/Galaxy__M51__/6xua/INS/M515FXXU6DXJ1/M515FODM6DXJ1
- TrebleDroid Samsung sepolicy:
  https://deepwiki.com/phhusson/device_phh_treble/5.2-vendor-specific-security-policies
- A54 GSI overlay (template for m51 RRO):
  https://xdaforums.com/t/overlay-gsi-a54-gsi-overlay.4700440/post-89783358
- HyperOS 3 telemetry / Security Center + XSOF (service inventory):
  https://thecybersecguru.com/analysis/hyperos-3-telemetry/
- MysticGSI HyperOS 3 listings: https://t.me/s/mysticgsi
- A71 HyperOS 2 thread (seelenchik, XDA, 2025-06-29, 40 replies) — OP body
  not retrieved in full; bug list corroborated from the Droidwin guide for
  the same FoxetGSI image and the same team's HyperSonic/AMIUI A71 thread.
