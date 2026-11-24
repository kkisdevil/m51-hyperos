# Blob audit — Galaxy M51 vendor blobs (913 entries)

Date: 2026-11-24. Pins: `a71-devs/android_device_samsung_m51` lineage-22.2
`55df7b4a` (proprietary-files.txt, 180 entries) +
`a71-devs/android_device_samsung_a71-common` lineage-22.2 `48e5e36e`
(proprietary-files.txt, 733 entries). Vendor repos pinned in
`trees/manifest.json`: `android_vendor_samsung_m51` `de409289`,
`android_vendor_samsung_a71-common` `407f21e5`.

## Headline answer — can we modify everything?

**No. Not the complete source.** Of the 913 entries:

| Bucket | Count | Meaning |
|---|---|---|
| **A — source-built in tree** | 29 HALs/services (not in the 913; listed separately below) | Real source. Modify freely. |
| **B — prebuilt blob, open replacement exists** | **30** | Drop the blob, use the named open component. |
| **C — prebuilt blob, binary-only** | **732** | No source, no replacement. Shim / wrapper / binary patch only. |
| **D — firmware / config / data, not code** | **151** | Editable as data, not compilable source. |
| **Total** | **913** | |

So **80% (732/913) of the vendor files are binary-only code**. The
things you *can* change from source are: the **kernel** (full source,
already building — crDroid 4.14.357-openela, see `docs/kernel-build.md`),
the **29 source-built HALs/services** in bucket A, the **30 replaceable
blobs** in bucket B, and the **151 data/config files** in bucket D
(text configs directly; binary calibration/firmware only by
re-extraction or vendor tooling).

The 732 binary-only blobs are the heart of the hardware: the modem/RIL
(`libsec-ril.so`), the Adreno GPU userspace, the whole CamX camera
pipeline (191 entries), the QTI location stack, Widevine, the TrustZone
libraries, the sensor hub stack, the DSP code. **A compiled binary
cannot be turned back into its original source.** Decompiling
(Ghidra/IDA) gives assembly and rough pseudo-C, not the source — and
you cannot rebuild a working driver from decompiled output. That is a
property of compiled code, not a missing tool.

What this means for the port: the port plan was already built around
this fact (reverse-engineering.md §4, port-plan.md L1–L6). Nothing in
this audit changes the plan — it confirms it: keep the blob stack as
the hardware floor, build the open layers on top of it (kernel source,
source HAL services, shims, RRO overlays, smali patches), and replace
only the 30 blobs in bucket B.

## Bucket A — source-built HALs/services (not blobs)

These come from `a71-common/common.mk` + `m51/device.mk` at the pinned
commits (`PRODUCT_PACKAGES`). They are **not** part of the 913 — do not
double-count them. Most are service layers that **wrap a blob
underneath**: the service is modifiable source, the engine it calls
into is still a blob (noted per row). That is the normal LineageOS
pattern and it is exactly where our modification leverage lives.

| Module | What | Source |
|---|---|---|
| `android.hardware.audio@6.0-impl.sm6150, android.hardware.audio.effect@6.0-impl, android.hardware.audio.service` | Audio HAL (QTI sm6150) | LineageOS hardware/qcom/audio (open) + AOSP frameworks/av |
| `audio.primary.sm6150:32, audio.primary.default, audio.r_submix.default, audio.usb.default, audio.bluetooth.default` | Audio primary HALs | LineageOS hardware/qcom/audio + AOSP (open) |
| `android.hardware.bluetooth.audio-impl` | Bluetooth audio HAL | AOSP (open) |
| `android.hardware.camera.provider-service_32.samsung` | Camera provider service (HIDL 2.6) | LineageOS hardware/samsung (open) — wraps the CamX blob stack underneath |
| `android.hardware.biometrics.fingerprint-service.samsung` | Fingerprint service | LineageOS hardware/samsung (open) — wraps the Egis/Goodix/Synaptics sensor blobs underneath |
| `android.hardware.gatekeeper@1.0-impl / -service` | Gatekeeper service | AOSP (open) — wraps Samsung's gatekeeper.mdfpp.so blob underneath |
| `android.hardware.graphics.composer@2.4-hal / -service, android.hardware.graphics.mapper@3.0-impl-qti-display, mapper@4.0-impl-qti-display, hwcomposer.qcom, gralloc.qcom, vendor.qti.hardware.display.allocator-service` | Display composer / gralloc / allocator | LineageOS hardware/qcom/display (open) — wraps the SDM blob libs underneath |
| `android.hardware.drm-service.clearkey` | ClearKey DRM service (AIDL) | AOSP (open) |
| `android.hardware.health-service.samsung (+ -recovery), vendor.lineage.health-service.default` | Health HAL | LineageOS hardware/samsung + vendor/lineage (open) |
| `android.hardware.keymaster@4.0-service.samsung` | Keymaster service | LineageOS hardware/samsung (open) — wraps the libskeymaster4device blob underneath |
| `android.hardware.light-service.samsung` | Lights HAL | LineageOS hardware/samsung (open) |
| `android.hardware.power-service.pixel-libperfmgr` | Power HAL | Pixel libperfmgr (hardware/google/pixel, open) |
| `android.hardware.sensors-service.samsung-multihal` | Sensors multihal service | In-tree: device/samsung/a71-common/sensors/ (Sensor.cpp, SensorsSubHal.cpp) — wraps the QTI SSC blob stack underneath |
| `android.hardware.usb-service.samsung, android.hardware.usb@1.3-service.dual_role_usb` | USB HAL | LineageOS hardware/samsung (open) |
| `android.hardware.vibrator-service.samsung` | Vibrator HAL | LineageOS hardware/samsung (open) |
| `android.hardware.wifi-service, libwifi-hal-qcom, libwpa_client, wpa_supplicant, hostapd` | Wi-Fi service + HAL | AOSP + LineageOS hardware/qcom/wlan (open) |
| `android.hardware.nfc@1.2-service.samsung, libnfc-nci, libnfc_nci_jni` | NFC service | LineageOS hardware/samsung + AOSP (open) |
| `vendor.lineage.fastcharge@1.0-service.samsung` | Fast-charge HAL | LineageOS vendor/lineage (open) |
| `vendor.lineage.livedisplay@2.0-service.samsung-qcom.sm6150` | LiveDisplay service | In-tree: device/samsung/a71-common/livedisplay/ |
| `vendor.lineage.touch@1.0-service.sm6150` | Touchscreen features service | In-tree: device/samsung/a71-common/touch/ |
| `vendor.qti.hardware.memtrack-service` | Memory-track HAL | LineageOS hardware/qcom (open) |
| `libOmxCore, libOmxVdec, libOmxVenc, libOmxVidcCommon, libstagefrighthw, libc2dcolorconvert` | Media codec (OMX) stack | LineageOS hardware/qcom/media (open) |
| `libsensorndkbridge, libshim_sensorndkbridge, libcrypto_shim.vendor` | NDK sensor bridge + shims | In-tree: device/samsung/a71-common/shims/libsensorndkbridge/ (ASensorManager.cpp) + shim sources |
| `libqti-perfd-client` | Perf client library | LineageOS hardware/qcom (open) |
| `qti-telephony-hidl-wrapper, qti-telephony-utils, telephony-ext` | Telephony HIDL wrappers | LineageOS hardware/qcom (open) |
| `secril_config_svc, sehradiomanager` | Samsung RIL config services | LineageOS hardware/samsung (open) |
| `SamsungDoze, AdvancedDisplay, Tag, FM2, AntHalService-Soong, SamsungDAP, CneApp.libvndfwk_detect_jni.qti_vendor_symlink` | Samsung support apps/services | LineageOS hardware/samsung + device tree (open) |
| `init.*.sh / *.rc, fstab.qcom, ueventd.qcom.rc, libinit (init_sm7150.cpp)` | Init scripts + device init library | In-tree: device/samsung/a71-common/libinit/ + init/ (open) |

Sources verified 2026-11-24: `LineageOS/android_hardware_samsung`,
`LineageOS/android_hardware_qcom_audio`, `LineageOS/android_hardware_qcom_display`
(all 200 via GitHub API); in-tree paths verified from the a71-common
git tree at `48e5e36e` (`shims/libsensorndkbridge/`,
`sensors/Sensor.cpp`, `livedisplay/`, `touch/`, `libinit/`).

## Bucket B — prebuilt blob, open replacement exists (30)

Two kinds only, and only these — nothing else in the 913 has a
verifiable open replacement:

1. **Prebuilt copies of open-source libraries (8)** — the blob is just
   a compiled copy of public code; rebuild it from upstream instead of
   shipping Samsung's/Qualcomm's copy.
2. **Audio-effect libraries (22)** — the *function* (bass boost,
   virtualizer, reverb, resampling, 3D positioning) is provided by
   AOSP's open audio-effects framework
   ([frameworks/av/media/libeffects](https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/),
   verified live 2026-11-24), which the tree's source audio HAL
   already uses (`libqcomvisualizer`, `libqcomvoiceprocessing` are
   source-built). Samsung/QTI's exact tuning is lost; the function is
   not.

| Path | Origin | Vendor | What it does | How it can be modified |
|---|---|---|---|---|
| `vendor/lib/lib_SoundAlive_3DPosition_ver202.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/lib_SoundAlive_SRC384_ver320.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/lib_SoundAlive_play_plus_ver400.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/lib_SoundBooster_ver1050.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/lib_soundaliveresampler.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/lib_SoundAlive_3DPosition_ver202.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/lib_SoundAlive_play_plus_ver400.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/lib_SoundBooster_ver1050.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/soundfx/libaudiosaplus_sec.so` | a71-common | Samsung | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/soundfx/libmysound.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/soundfx/libmyspace.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/soundfx/libqcbassboost.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/soundfx/libqcreverb.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/soundfx/libqcvirt.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/soundfx/libsamsungSoundbooster_plus.so` | a71-common | Samsung | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/soundfx/libaudiosaplus_sec.so` | a71-common | Samsung | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/soundfx/libmysound.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/soundfx/libmyspace.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/soundfx/libqcbassboost.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/soundfx/libqcreverb.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/soundfx/libqcvirt.so` | a71-common | — | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/soundfx/libsamsungSoundbooster_plus.so` | a71-common | Samsung | Audio effect — function covered by AOSP's open effects framework. Audio effect whose function is provided by the AOSP audio effects framework (frameworks/av/media/libeffects) (https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libeffects/) — standard bass boost / virtualizer / reverb / resampler, already used by the tree's source audio HAL. Samsung/QTI tuning is lost, the function is not. | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/libc++_shared.so` | a71-common | — | Prebuilt copy of open-source LLVM libc++. Upstream source: https://libcxx.llvm.org/ | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/libtinyxml2_1.so` | a71-common | — | Prebuilt copy of open-source tinyxml2. Upstream source: https://github.com/leethomason/tinyxml2 | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/libtinyxml2_1.so` | a71-common | — | Prebuilt copy of open-source tinyxml2. Upstream source: https://github.com/leethomason/tinyxml2 | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/libxml.so` | a71-common | — | Prebuilt copy of open-source libxml2. Upstream source: https://gitlab.gnome.org/GNOME/libxml2 | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/libxml.so` | a71-common | — | Prebuilt copy of open-source libxml2. Upstream source: https://gitlab.gnome.org/GNOME/libxml2 | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/libnanopb.so` | a71-common | — | Prebuilt copy of open-source nanopb. Upstream source: https://github.com/nanopb/nanopb | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib/libqcbor.so` | a71-common | — | Prebuilt copy of open-source QCBOR. Upstream source: https://github.com/laurencelundblade/QCBOR | Replace with the open component; drop the blob from the vendor tree. |
| `vendor/lib64/libqcbor.so` | a71-common | — | Prebuilt copy of open-source QCBOR. Upstream source: https://github.com/laurencelundblade/QCBOR | Replace with the open component; drop the blob from the vendor tree. |

**Deliberately NOT in B** (common mistakes, all stay in C — see § Honest
limits): the CamX/Samsung camera libraries (GCam replaces the camera
*app*, not the camera HAL — every photo still goes through the CamX
blob stack); the Adreno GPU userspace (Freedreno/Turnip exists but is
not a drop-in replacement for this vendor stack — see below); the GNSS
stack (the AOSP GNSS *service* is open, but it needs QTI's location
engine underneath); the Bluetooth stack (AOSP BT is open, but the QTI
vendor impl that talks to the WCNSS chip is a blob).

## Bucket C — prebuilt blob, binary-only (732)

No source, no drop-in open replacement. Modification routes, in order
of preference: (1) leave it alone and work at the source service layer
above it (bucket A); (2) a **shim** — a small source-built library
that interposes between the caller and the blob (the tree already does
this: `libsensorndkbridge`, `libshim_sensorndkbridge`,
`libcrypto_shim.vendor`); (3) a **wrapper/proxy HAL** that translates
the old HIDL interface to what the GSI expects; (4) a **binary patch**
— edit the compiled bytes (string, constant, branch), the last resort,
fragile across re-extraction.

### Rollup by subsystem (C)

| Count | Subsystem |
|---|---|
| 191 | Camera |
| 78 | GNSS |
| 46 | Audio |
| 36 | RIL |
| 36 | TrustZone |
| 34 | Graphics (Adreno) |
| 30 | Qualcomm MSM Interface |
| 25 | Sensors |
| 19 | DSP |
| 18 | Display Postprocessing |
| 16 | ADSP Modules |
| 16 | DRM |
| 16 | SCVE |
| 14 | Fingerprint |
| 14 | Bluetooth |
| 14 | Display (SDM) |
| 13 | Soundtrigger |
| 13 | VPP |
| 12 | Neural Networks |
| 10 | Audio SoundFX |
| 10 | CVP |
| 9 | Machine Learning |
| 8 | Bluetooth (A2DPSINK) |
| 7 | Thermal |
| 5 | ADSP |
| 4 | Display (HDR) |
| 4 | Peripheral Manager |
| 4 | RIL - From a23xqnsxx-user 14 UP1A.231005.007 A236BXXS9EYA1 release-keys |
| 4 | Time |
| 3 | Configstore |
| 3 | OMX |
| 3 | Power |
| 3 | Trusted User Interface |
| 2 | Bluetooth (ANT+) |
| 2 | FM |
| 2 | Graphics (Vulkan) |
| 2 | Keymaster |
| 2 | SEC |
| 2 | WiFi |
| 1 | Charger |
| 1 | Gatekeeper |

### Full table (C, 732 rows)

| Path | Origin | Vendor | What it does | How it can be modified |
|---|---|---|---|---|
| `vendor/lib/libFacePreProcessing.camera.samsung.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libFacePreProcessing.camera.samsung.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libFacialStickerEngine.arcsoft.so` | m51 | ArcSoft | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.camx.chiiqutils.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.eisv2.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.eisv3.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.depth.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.dummyrtb.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.dummysat.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.eisv2.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.eisv3.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.fcv.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.gpu.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.memcpy.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.stich.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.node.swregistration.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.aec.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.af.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.afd.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.asd.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.awb.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.haf.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.hafoverride.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.pdlib.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.pdlibsony.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qti.stats.pdlibwrapper.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qtistatic.stats.aec.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qtistatic.stats.af.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qtistatic.stats.awb.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.qtistatic.stats.pdlib.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.bayercheck.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.bayerfuse.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.capture_bokeh.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.capture_fusion.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.realtimebokeh.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.remosaic.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.smooth_transition.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.uniplugin_capture.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.uniplugin_preview.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.uniplugin_recording.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.samsung.node.uniplugin_vdis.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.wrapper.stats.aec.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.wrapper.stats.af.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.wrapper.stats.awb.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/com.wrapper.stats.pdlib.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/libdepthmapwrapper.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/components/libmmcamera_cac3.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/com.qti.eeprom.n24s64b_imx616.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/com.samsung.sensor.gc5035.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/com.samsung.sensor.gc5035_macro.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/com.samsung.sensor.imx616.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/com.samsung.sensor.imx682.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/camera/com.samsung.sensor.s5k3l6.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.camx.chiiqutils.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.eisv2.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.eisv3.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.depth.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.dummyrtb.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.dummysat.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.eisv2.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.eisv3.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.fcv.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.gpu.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.memcpy.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.stich.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.node.swregistration.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.stats.afd.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.stats.asd.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.stats.hafoverride.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.stats.pdlibsony.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qti.stats.pdlibwrapper.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qtistatic.stats.aec.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qtistatic.stats.af.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qtistatic.stats.awb.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.qtistatic.stats.pdlib.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.samsung.node.bayercheck.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.samsung.node.bayerfuse.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.samsung.node.capture_bokeh.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.samsung.node.capture_fusion.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.samsung.node.realtimebokeh.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.samsung.node.remosaic.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.samsung.node.smooth_transition.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.wrapper.stats.aec.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.wrapper.stats.af.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.wrapper.stats.awb.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/com.wrapper.stats.pdlib.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/libdepthmapwrapper.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/components/libmmcamera_cac3.so` | m51 | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/com.qti.eeprom.n24s64b_imx616.so` | m51 | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/com.samsung.sensor.gc5035.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/com.samsung.sensor.gc5035_macro.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/com.samsung.sensor.imx616.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/com.samsung.sensor.imx682.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/camera/com.samsung.sensor.s5k3l6.so` | m51 | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libbauthserver.so` | m51 | — | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libbauthtzcommon.so` | m51 | — | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libegis_fp_normal_sensor_test.so` | m51 | EgisTec | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgf_in_system_lib.so` | m51 | Goodix | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqfp_sensortest.so` | m51 | — | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsynaFpSensorTestNwd.so` | m51 | Synaptics | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.fingerprint@1.0.so` | m51 | Qualcomm | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libbauthserver.so` | m51 | — | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libbauthtzcommon.so` | m51 | — | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libegis_fp_normal_sensor_test.so` | m51 | EgisTec | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgf_in_system_lib.so` | m51 | Goodix | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqfp_sensortest.so` | m51 | — | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsynaFpSensorTestNwd.so` | m51 | Synaptics | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.fingerprint@1.0.so` | m51 | Qualcomm | Fingerprint sensor library (TrustZone / sensor test). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/factory.ssc` | m51 | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/sensors.grip.so` | m51 | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/sensors.grip.so` | m51 | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/adsprpcd` | a71-common | — | ADSP (Hexagon DSP) RPC runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libadsp_default_listener.so` | a71-common | — | ADSP (Hexagon DSP) RPC runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libadsprpc.so` | a71-common | — | ADSP (Hexagon DSP) RPC runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libadsp_default_listener.so` | a71-common | — | ADSP (Hexagon DSP) RPC runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libadsprpc.so` | a71-common | — | ADSP (Hexagon DSP) RPC runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/capi_v2_aptX_CLHDAD_Encoder.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libVC1Dec.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libVC1DecDsp_skel.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libapps_mem_heap.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libcamera_nn_skel.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libcvpdsp_skel.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libdspCV_skel.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libdsp_streamer_skel.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libfastcvadsp.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libfastcvdsp_skel.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libhexagon_nn_skel.so` | a71-common | Qualcomm | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libhexagon_nn_skel_secondary.so` | a71-common | Samsung | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libscveObjectSegmentation_skel.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libscveT2T_skel.so` | a71-common | — | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libsnpe_dsp_v65_domains_v2_skel.so` | a71-common | Qualcomm | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/rfsa/adsp/libsnpe_dsp_v66_domains_v2_skel.so` | a71-common | Qualcomm | DSP-side module loaded on the Hexagon DSP. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `system_ext/framework/audiosphere.jar` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/audio.primary.qcom.so` | a71-common | Qualcomm | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/audio.sec_primary.default.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/vendor.samsung.hardware.audio@1.0-impl.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/lib_SamsungRec_07010.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/lib_SoundAlive_AlbumArt_ver105.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libacdb-fts.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libacdbloader.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libacdbrtac.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libadiertac.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libadm.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libaudcal.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libaudio_log_utils.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libaudioalsa.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libaudioconfigstore.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libaudioparsers.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdrc.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libprofileparamstorage.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqtigef.so` | a71-common | Qualcomm | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/librecordalive.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsamsungVoipResampler.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsecaudiocoreutils.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsecaudioinfo.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libspatializerparamstorage.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libspeakercalibration.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsurround_3mic_proc.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.audiohalext@1.0.so` | a71-common | Qualcomm | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.samsung.hardware.audio@1.0.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/audio.sec_primary.default.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/vendor.samsung.hardware.audio@1.0-impl.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/lib_SoundAlive_AlbumArt_ver105.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libacdb-fts.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libacdbloader.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libacdbrtac.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libadiertac.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libaudcal.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libaudioalsa.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libaudioconfigstore.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libaudioparsers.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libprofileparamstorage.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqtigef.so` | a71-common | Qualcomm | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsecaudiocoreutils.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsecaudioinfo.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libspatializerparamstorage.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libspeakercalibration.so` | a71-common | — | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.audio@1.0.so` | a71-common | Samsung | Audio HAL / calibration / Samsung audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/soundfx/libasphere.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/soundfx/libaudioeffectoffload.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/soundfx/libplaybackrecorder.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/soundfx/libshoebox.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/soundfx/libswdap.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/soundfx/libasphere.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/soundfx/libaudioeffectoffload.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/soundfx/libplaybackrecorder.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/soundfx/libshoebox.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/soundfx/libswdap.so` | a71-common | — | Audio effect library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/android.hardware.bluetooth@1.0-service-qti` | a71-common | Qualcomm | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/android.hardware.bluetooth@1.0-impl-qti.so` | a71-common | Qualcomm | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/vendor.samsung.hardware.bluetooth.a2dp@1.0-impl.so` | a71-common | Samsung | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libbluetooth_audio_session_qti.so` | a71-common | Qualcomm | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.bluetooth_sar@1.0.so` | a71-common | Qualcomm | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.samsung.hardware.bluetooth.a2dp@1.0.so` | a71-common | Samsung | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.samsung.hardware.bluetooth@2.0.so` | a71-common | Samsung | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/android.hardware.bluetooth@1.0-impl-qti.so` | a71-common | Qualcomm | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/vendor.samsung.hardware.bluetooth.a2dp@1.0-impl.so` | a71-common | Samsung | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libbluetooth_audio_session_qti.so` | a71-common | Qualcomm | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libbtnv.so` | a71-common | — | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.bluetooth_sar@1.0.so` | a71-common | Qualcomm | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.bluetooth.a2dp@1.0.so` | a71-common | Samsung | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.bluetooth@2.0.so` | a71-common | Samsung | Bluetooth HAL / QTI BT stack library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/audio.a2dpsink.default.so` | a71-common | — | Bluetooth A2DP-sink audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/vendor.samsung.hardware.bluetooth.a2dpsink@1.0-impl.so` | a71-common | Samsung | Bluetooth A2DP-sink audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libbluetooth_a2dpsink_session.so` | a71-common | — | Bluetooth A2DP-sink audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.samsung.hardware.bluetooth.a2dpsink@1.0.so` | a71-common | Samsung | Bluetooth A2DP-sink audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/audio.a2dpsink.default.so` | a71-common | — | Bluetooth A2DP-sink audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/vendor.samsung.hardware.bluetooth.a2dpsink@1.0-impl.so` | a71-common | Samsung | Bluetooth A2DP-sink audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libbluetooth_a2dpsink_session.so` | a71-common | — | Bluetooth A2DP-sink audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.bluetooth.a2dpsink@1.0.so` | a71-common | Samsung | Bluetooth A2DP-sink audio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/com.qualcomm.qti.ant@1.0.so` | a71-common | Qualcomm | ANT+ radio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/com.qualcomm.qti.ant@1.0.so` | a71-common | Qualcomm | ANT+ radio library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/camera.qcom.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/com.samsung.chi.override.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libBeauty_v4.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libDualCamBokehCapture.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libHprFace_GAE_api.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libHpr_RecGAE_cvFeature_v1.0.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libLocalTM_capture_core.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libLocalTM_wrapper.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libOpenCv.camera.samsung.so` | a71-common | Samsung | Samsung build of open-source OpenCV — upstream exists (github.com/opencv/opencv) but the Samsung camera glue is not upstream, so this blob cannot be rebuilt from it. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libarcsoft_stereodistancemeasure.so` | a71-common | ArcSoft | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libbeautyshot.arcsoft.so` | a71-common | ArcSoft | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcamera_nn_stub.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcamxfdalgov7.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcamxfdalgov8.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcamxfdengine.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcamxstatscore.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcamxswprocessalgo.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcamxtintlessalgo.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libchiss3alogdebug.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcom.qti.chinodeutils.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdualcam_optical_zoom.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdualcam_optical_zoom_control.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdualcam_refocus_image.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdualcam_refocus_video.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdualcapture.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libhigh_dynamic_range.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libhigh_dynamic_range_bokeh.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libjpegQtable_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblivefocus_capture_engine.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblivefocus_capture_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblivefocus_preview_engine.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblivefocus_preview_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libllhdr_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblow_light_hdr.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libmpbase.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libpadm.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqcwrappercommon.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsavscmn.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsmartfocus_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsmartfocusengine.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsnap_vndk.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libswldc_capture_core.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libswregistrationalgo.so` | a71-common | EgisTec | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libuniplugin.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libvdis_core.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libvdis_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/camera.qcom.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/com.samsung.chi.override.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libBeauty_v4.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libDLInterface.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libDualCamBokehCapture.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libHprFace_GAE_api.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libHpr_RecGAE_cvFeature_v1.0.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libLocalTM_capture_core.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libLocalTM_preview_core.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libLocalTM_wrapper.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libOpenCv.camera.samsung.so` | a71-common | Samsung | Samsung build of open-source OpenCV — upstream exists (github.com/opencv/opencv) but the Samsung camera glue is not upstream, so this blob cannot be rebuilt from it. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libSNPE.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libbeautyshot.arcsoft.so` | a71-common | ArcSoft | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcamera_nn_stub.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcamxfdalgov7.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcamxfdalgov8.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcamxfdengine.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcamxstatscore.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcamxswprocessalgo.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcamxtintlessalgo.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libchiss3alogdebug.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcom.qti.chinodeutils.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdualcam_optical_zoom.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdualcam_optical_zoom_control.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdualcam_refocus_image.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdualcapture.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhal.wsm.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhigh_dynamic_range.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhigh_dynamic_range_bokeh.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libjnihelper.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libjpegQtable_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblivefocus_capture_engine.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblivefocus_capture_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblow_light_hdr.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libmpbase.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libpadm.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqcwrappercommon.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libremosaic_daemon.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libremosaiclib.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsavscmn.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsmartfocus_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsmartfocusengine.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsnap_v1.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsnap_vndk.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsnpe_dsp_domains_v2.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsnpe_wrapper.so` | a71-common | Qualcomm | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libswldc_capture_core.camera.samsung.so` | a71-common | Samsung | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libswregistrationalgo.so` | a71-common | EgisTec | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libuniplugin.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libvdis_core.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libvdis_interface.so` | a71-common | — | Camera pipeline library (CamX/Samsung sensor stack). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hvdcp_opti` | a71-common | — | Charger (HVDCP) binary. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcvp.so` | a71-common | — | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcvp_common.so` | a71-common | — | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcvp_stub.so` | a71-common | — | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcvpcpuRev_skel.so` | a71-common | — | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.cvp@1.0.so` | a71-common | Qualcomm | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcvp.so` | a71-common | — | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcvp_common.so` | a71-common | — | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcvp_stub.so` | a71-common | — | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcvpcpuRev_skel.so` | a71-common | — | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.cvp@1.0.so` | a71-common | Qualcomm | Computer-vision (CVP) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/vendor.qti.hardware.capabilityconfigstore@1.0-service` | a71-common | Qualcomm | QTI capability-configstore HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/vendor.qti.hardware.capabilityconfigstore@1.0-impl.so` | a71-common | Qualcomm | QTI capability-configstore HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/vendor.qti.hardware.capabilityconfigstore@1.0-impl.so` | a71-common | Qualcomm | QTI capability-configstore HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libhdr_tm.so` | a71-common | — | Display HDR / colour-management library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsdm-colormgr-algo.so` | a71-common | — | Display HDR / colour-management library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhdr_tm.so` | a71-common | — | Display HDR / colour-management library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsdm-colormgr-algo.so` | a71-common | — | Display HDR / colour-management library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdisplayqos.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqseed3.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsdedrm.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsdm-color.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsdm-diag.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsdm-disp-vndapis.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsdmextension.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdisplayqos.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqseed3.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsdedrm.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsdm-color.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsdm-diag.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsdm-disp-vndapis.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsdmextension.so` | a71-common | — | QTI display (SDM) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/vendor.display.color@1.0-service` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/ppd` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdisp-aba.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.display.color@1.0.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.display.color@1.1.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.display.color@1.2.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.display.color@1.3.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.display.color@1.4.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.display.color@1.5.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.display.postproc@1.0.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdisp-aba.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.display.color@1.0.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.display.color@1.1.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.display.color@1.2.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.display.color@1.3.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.display.color@1.4.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.display.color@1.5.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.display.postproc@1.0.so` | a71-common | — | Display colour/post-processing HAL. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/android.hardware.drm@1.3-service.clearkey` | a71-common | — | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/android.hardware.drm@1.3-service.widevine` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hdcp1prov` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hdcp2p2prov` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/mediadrm/libwvdrmengine.so` | a71-common | Qualcomm | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcpion.so` | a71-common | — | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libhdcp1prov.so` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libhdcp2p2prov.so` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libhdcpsrm.so` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liboemcrypto.so` | a71-common | Qualcomm | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libwvhidl.so` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcpion.so` | a71-common | — | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhdcp1prov.so` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhdcp2p2prov.so` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhdcpsrm.so` | a71-common | Google/Widevine | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liboemcrypto.so` | a71-common | Qualcomm | DRM / Widevine / HDCP library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/cdsprpcd` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/dspservice` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcdsp_default_listener.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcdsprpc.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libfastcrc.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libfastcvdsp_stub.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libfastcvopt.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libmdsprpc.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsdsprpc.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsysmon_cdsp_skel.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.dsp@1.0.so` | a71-common | Qualcomm | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcdsp_default_listener.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcdsprpc.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libfastcvdsp_stub.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libfastcvopt.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libmdsprpc.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsdsprpc.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsysmon_cdsp_skel.so` | a71-common | — | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.dsp@1.0.so` | a71-common | Qualcomm | CDSP (compute DSP) runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.fm@1.0.so` | a71-common | Qualcomm | FM radio HAL library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.fm@1.0.so` | a71-common | Qualcomm | FM radio HAL library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/gatekeeper.mdfpp.so` | a71-common | — | Gatekeeper (TrustZone) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/app/CACertService/CACertService.apk` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/android.hardware.gnss@2.1-service-qti` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/loc_launcher` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/lowi-server` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/xtra-daemon` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/android.hardware.gnss@2.1-impl-qti.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/vendor.samsung.hardware.gnss@2.0-impl-sec.so` | a71-common | Samsung | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libbatching.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcacertclient.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcdfw.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcdfw_remote_api.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdataitems.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libfloatingfeature.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgeofencing.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgnss.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgnsspps.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgps.utils.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libizat_client_api.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libizat_core.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblbs_core.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libloc_api_v02.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libloc_core.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libloc_socket.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblocation_api.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblocationservice.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblocationservice_glue.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/liblowi_client.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libpdmapper.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqcc_file_agent.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsemnativecarrierfeature.so` | a71-common | Samsung | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsynergy_loc_api.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.gnss@1.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.gnss@1.1.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.gnss@1.2.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.gnss@2.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.gnss@2.1.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.gnss@3.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.gnss@4.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.cacert@1.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.qccsyshal@1.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.samsung.hardware.gnss@2.0.so` | a71-common | Samsung | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/android.hardware.gnss@2.1-impl-qti.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/vendor.samsung.hardware.gnss@2.0-impl-sec.so` | a71-common | Samsung | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libbatching.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcacertclient.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcdfw.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcdfw_remote_api.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdataitems.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libfloatingfeature.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgeofencing.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgnss.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgnsspps.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgps.utils.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libizat_client_api.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libizat_core.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblbs_core.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libloc_api_v02.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libloc_core.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libloc_socket.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblocation_api.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblocationservice.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblocationservice_glue.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblowi_client.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libpdmapper.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqcc_file_agent.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqdma_file_agent.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsemnativecarrierfeature.so` | a71-common | Samsung | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsynergy_loc_api.so` | a71-common | — | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.gnss@1.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.gnss@1.1.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.gnss@1.2.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.gnss@2.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.gnss@2.1.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.gnss@3.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.gnss@4.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.cacert@1.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.qccsyshal@1.0.so` | a71-common | Qualcomm | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.gnss@2.0.so` | a71-common | Samsung | GNSS / location-stack library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/egl/libEGL_adreno.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). Binary-only prebuilt code — no source, no drop-in open replacement. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/egl/libGLESv2_adreno.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). Binary-only prebuilt code — no source, no drop-in open replacement. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/egl/libq3dtools_adreno.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). Binary-only prebuilt code — no source, no drop-in open replacement. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/egl/eglSubDriverAndroid.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/egl/libGLESv1_CM_adreno.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/egl/libq3dtools_esx.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libC2D2.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libCB.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libOpenCL.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libVkLayer_q3dtools.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libadreno_utils.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libc2d30_bltlib.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgpudataproducer.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgsl.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libllvm-glnext.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libllvm-qcom.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libpvr.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/egl/libEGL_adreno.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). Binary-only prebuilt code — no source, no drop-in open replacement. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/egl/libGLESv2_adreno.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). Binary-only prebuilt code — no source, no drop-in open replacement. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/egl/libq3dtools_adreno.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). Binary-only prebuilt code — no source, no drop-in open replacement. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/egl/eglSubDriverAndroid.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/egl/libGLESv1_CM_adreno.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/egl/libq3dtools_esx.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libC2D2.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libCB.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libOpenCL.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libVkLayer_q3dtools.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libadreno_utils.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libc2d30_bltlib.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgpudataproducer.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgsl.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libllvm-glnext.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libllvm-qcom.so` | a71-common | Qualcomm | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libpvr.so` | a71-common | — | Adreno GPU userspace (EGL/GLES/OpenCL/Vulkan support). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/vulkan.adreno.so` | a71-common | Qualcomm | Adreno Vulkan driver. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/vulkan.adreno.so` | a71-common | Qualcomm | Adreno Vulkan driver. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libkeymaster_helper.so` | a71-common | — | Keymaster (TrustZone) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libskeymaster4device.so` | a71-common | — | Keymaster (TrustZone) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libperfconfig.so` | a71-common | — | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libperfgluelayer.so` | a71-common | — | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqti-util.so` | a71-common | Qualcomm | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/liblearningmodule.so` | a71-common | — | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libmeters.so` | a71-common | — | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libperfconfig.so` | a71-common | — | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libperfgluelayer.so` | a71-common | — | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqti-util.so` | a71-common | Qualcomm | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libreffeature.so` | a71-common | — | QTI performance / learning-module library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/npu_launcher` | a71-common | — | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libhta_hexagon_runtime.so` | a71-common | Qualcomm | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libnpu.so` | a71-common | — | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/unnhal-acc-hta.so` | a71-common | — | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhexagon_nn_stub.so` | a71-common | Qualcomm | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhta.so` | a71-common | — | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhta_hexagon_runtime.so` | a71-common | Qualcomm | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libnpu.so` | a71-common | — | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/unnhal-acc-adreno.so` | a71-common | Qualcomm | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/unnhal-acc-common.so` | a71-common | — | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/unnhal-acc-hta.so` | a71-common | — | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/unnhal-acc-hvx.so` | a71-common | — | NPU / Hexagon NN runtime library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libOmxVpp.so` | a71-common | — | Media codec (OMX) support library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libmmosal.so` | a71-common | — | Media codec (OMX) support library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libmmosal.so` | a71-common | — | Media codec (OMX) support library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/pm-proxy` | a71-common | — | QTI peripheral-manager client/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/pm-service` | a71-common | — | QTI peripheral-manager client/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libperipheral_client.so` | a71-common | — | QTI peripheral-manager client/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libperipheral_client.so` | a71-common | — | QTI peripheral-manager client/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `system/bin/lpm` | a71-common | — | Power / low-power-mode library or binary. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `system/lib64/libmaet.so` | a71-common | — | Power / low-power-mode library or binary. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `system/lib64/libsxqk_skia.so` | a71-common | — | Power / low-power-mode library or binary. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/irsc_util` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/pd-mapper` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdiag.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdsutils.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libidl.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqdi.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqdp.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqmi.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqmi_cci.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqmi_client_helper.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqmi_client_qmux.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqmi_common_so.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqmi_csi.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqmi_encdec.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqmiservices.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdiag.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdsutils.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libidl.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqdi.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqdp.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmi.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmi_cci.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmi_client_helper.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmi_client_qmux.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmi_common_so.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmi_csi.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmi_encdec.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmiservices-ext.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmiservices-sem-ext.so` | a71-common | Samsung | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqmiservices.so` | a71-common | — | QMI / QRTR modem-transport library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/rild` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/adpl` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/netmgrd` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/qrtr-cfg` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/qrtr-lookup` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/qrtr-ns` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/rmt_storage` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/tftp_server` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libconfigdb.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdsi_netctrl.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libmdmdetect.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libnetmgr.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libnetmgr_common.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libpdnotifier.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqcmaputils.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqrtr.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqsocket.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.data.connection@1.0.so` | a71-common | Qualcomm | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.data.connection@1.1.so` | a71-common | Qualcomm | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libSemDataProps.so` | a71-common | Samsung | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libconfigdb.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdsi_netctrl.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libengmode_client.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libmdmdetect.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libnetmgr.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libnetmgr_common.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libpdnotifier.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqcmaputils.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqrtr.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqsocket.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libvkmanager_vendor.so` | a71-common | — | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.data.connection@1.0.so` | a71-common | Qualcomm | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.data.connection@1.1.so` | a71-common | Qualcomm | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.radio.bridge@2.0.so` | a71-common | Samsung | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.radio.bridge@2.1.so` | a71-common | Samsung | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.radio.channel@2.0.so` | a71-common | Samsung | RIL / modem data-path library or daemon. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libnlnetmgr.so` | a71-common | — | Samsung RIL library (taken from the A23 stock build, newer than the m51 dump). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libril_sem.so` | a71-common | Samsung | Samsung RIL library (taken from the A23 stock build, newer than the m51 dump). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libSemTelephonyProps.so` | a71-common | Samsung | Samsung RIL library (taken from the A23 stock build, newer than the m51 dump). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsec-ril.so` | a71-common | Samsung | Samsung RIL library (taken from the A23 stock build, newer than the m51 dump). | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libscveCommon.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libscveCommon_stub.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libscveObjectSegmentation.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libscveObjectSegmentation_stub.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libscveObjectTracker.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libscveObjectTracker_stub.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.scve.objecttracker@1.0.so` | a71-common | Qualcomm | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.scve.panorama@1.0.so` | a71-common | Qualcomm | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libscveCommon.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libscveCommon_stub.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libscveObjectSegmentation.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libscveObjectSegmentation_stub.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libscveObjectTracker.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libscveObjectTracker_stub.so` | a71-common | — | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.scve.objecttracker@1.0.so` | a71-common | Qualcomm | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.scve.panorama@1.0.so` | a71-common | Qualcomm | QTI computer-vision engine library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsecnativefeature.so` | a71-common | Samsung | Samsung native-feature library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsecnativefeature.so` | a71-common | Samsung | Samsung native-feature library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsensorlistener.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsensorslog.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsns_device_mode_stub.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsns_fastRPC_util.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsns_low_lat_stream_stub.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsns_registry_skel.so` | a71-common | EgisTec | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsnsapi.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsnsdiaglog.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libssc.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libssc_default_listener.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/sensors.ssc.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsensorlistener.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsensorslog.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsns_device_mode_stub.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsns_fastRPC_util.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsns_low_lat_stream_stub.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsns_registry_skel.so` | a71-common | EgisTec | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsnsapi.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsnsdiaglog.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libssc.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libssc_default_listener.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/sensors.ssc.so` | a71-common | — | Sensor-stack (SSC) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libaudio_soundtrigger.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcapiv2svacnn.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libcapiv2vop.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgcs-calwrapper.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgcs-ipc.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgcs-osal.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libgcs.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcapiv2svacnn.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libcapiv2vop.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgcs-calwrapper.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgcs-ipc.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgcs-osal.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libgcs.so` | a71-common | — | Sound-trigger (voice wake) library. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/vendor.samsung.hardware.thermal@1.0-service` | a71-common | Samsung | Thermal-engine / thermal HAL library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/thermal-engine` | a71-common | — | Thermal-engine / thermal HAL library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libthermalclient.so` | a71-common | — | Thermal-engine / thermal HAL library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libhypervintf.so` | a71-common | — | Thermal-engine / thermal HAL library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libthermalclient.so` | a71-common | — | Thermal-engine / thermal HAL library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.hyper-V2-ndk_platform.so` | a71-common | Samsung | Thermal-engine / thermal HAL library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.samsung.hardware.thermal@1.0.so` | a71-common | Samsung | Thermal-engine / thermal HAL library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/app/TimeService/TimeService.apk` | a71-common | — | Modem time service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/time_daemon` | a71-common | — | Modem time service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libtime_genoff.so` | a71-common | — | Modem time service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libtime_genoff.so` | a71-common | — | Modem time service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/vendor.qti.hardware.qseecom@1.0-service` | a71-common | Qualcomm | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/qseecomd` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/hw/vendor.qti.hardware.qseecom@1.0-impl.so` | a71-common | Qualcomm | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libGPTEE_vendor.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libGPreqcancel.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libGPreqcancel_svc.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libQSEEComAPI.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libSecureUILib.so` | a71-common | Samsung | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libStDrvInt.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdrmfs.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libdrmtime.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libminkdescriptor.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libops.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libqisl.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/librpmb.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsecureui.so` | a71-common | Samsung | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libsecureui_svcsock.so` | a71-common | Samsung | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libssd.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.qseecom@1.0.so` | a71-common | Qualcomm | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/hw/vendor.qti.hardware.qseecom@1.0-impl.so` | a71-common | Qualcomm | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libGPTEE_vendor.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libGPreqcancel.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libGPreqcancel_svc.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libQSEEComAPI.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libSecureUILib.so` | a71-common | Samsung | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libStDrvInt.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdrmfs.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libdrmtime.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libminkdescriptor.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libops.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libqisl.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/librpmb.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsecureui.so` | a71-common | Samsung | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libsecureui_svcsock.so` | a71-common | Samsung | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libssd.so` | a71-common | — | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.qseecom@1.0.so` | a71-common | Qualcomm | TrustZone (QSEE) library or service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/vendor.qti.hardware.tui_comm@1.0-service-qti` | a71-common | Qualcomm | TrustZone trusted-UI service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.tui_comm@1.0.so` | a71-common | Qualcomm | TrustZone trusted-UI service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.tui_comm@1.0.so` | a71-common | Qualcomm | TrustZone trusted-UI service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/vppservice` | a71-common | — | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libvppclient.so` | a71-common | — | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libvpphvx.so` | a71-common | — | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/libvpplibrary.so` | a71-common | — | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.vpp@1.1.so` | a71-common | Qualcomm | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.vpp@1.2.so` | a71-common | Qualcomm | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib/vendor.qti.hardware.vpp@1.3.so` | a71-common | Qualcomm | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libvppclient.so` | a71-common | — | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libvpphvx.so` | a71-common | — | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/libvpplibrary.so` | a71-common | — | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.vpp@1.1.so` | a71-common | Qualcomm | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.vpp@1.2.so` | a71-common | Qualcomm | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/lib64/vendor.qti.hardware.vpp@1.3.so` | a71-common | Qualcomm | Video post-processing library/service. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/hw/macloader` | a71-common | — | Wi-Fi daemon / loader. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |
| `vendor/bin/cnss-daemon` | a71-common | Qualcomm | Wi-Fi daemon / loader. | Shim / wrapper / binary patch only; or keep as-is and work around it at the HAL-service layer. |

## Bucket D — firmware / config / data, not code (151)

Editable as data, not compilable source. Text files (`.xml`, `.conf`,
`.json`, `.rc`, `.policy`) can be edited directly — this is real
leverage (audio policy, seccomp policy, sensor configs, init scripts,
thermal config). Binary data (`.acdb` calibration, `.bin` firmware and
tuning blobs) can only be changed by re-extracting from a different
stock build or with vendor tooling; you cannot compile them.

Special case: **11 entries in the m51 list are `DUMMY_SHARED_LIB`**
(`vendor/lib64/camera/com.samsung.sensormodule.*.bin` and
`com.samsung.tuned.*.bin`) — the build system generates an *empty*
`.so` stub for them so the linker is satisfied; no real code is
shipped for those paths. They are counted in D, not C.

### Rollup by subsystem (D)

| Count | Subsystem |
|---|---|
| 32 | Sensors |
| 25 | Camera |
| 13 | Qualcomm MSM Interface |
| 13 | RIL |
| 10 | GNSS |
| 9 | ACDB |
| 7 | IPA (Firmware) |
| 6 | Seccomp Policy |
| 4 | DRM |
| 3 | NFC (Firmware) |
| 3 | Camera (Firmware) |
| 3 | Graphics (Adreno firmware) |
| 3 | Thermal |
| 3 | WiFI (Firmware) |
| 2 | Bluetooth (Firmware) |
| 2 | DSP |
| 2 | TrustZone |
| 2 | VPP |
| 1 | ADSP |
| 1 | ADSP Configs |
| 1 | Bluetooth |
| 1 | Bluetooth (A2DPSINK) |
| 1 | Configstore |
| 1 | Display Postprocessing |
| 1 | Machine Learning |
| 1 | Time |
| 1 | Trusted User Interface |

### Full table (D, 151 rows)

| Path | Origin | Vendor | What it does | How it can be modified |
|---|---|---|---|---|
| `vendor/etc/audconf/OPEN/Bluetooth_cal.acdb` | m51 | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/audconf/OPEN/Codec_cal.acdb` | m51 | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/audconf/OPEN/General_cal.acdb` | m51 | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/audconf/OPEN/Global_cal.acdb` | m51 | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/audconf/OPEN/Handset_cal.acdb` | m51 | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/audconf/OPEN/Hdmi_cal.acdb` | m51 | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/audconf/OPEN/Headset_cal.acdb` | m51 | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/audconf/OPEN/Speaker_cal.acdb` | m51 | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/audconf/OPEN/workspaceFile.qwsp` | m51 | — | ACDB data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.sensormodule.0_sony_imx682.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.sensormodule.1_sony_imx616.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.sensormodule.2_lsi_s5k3l6.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.sensormodule.3_lsi_gc5035.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.sensormodule.4_lsi_gc5035_macro.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.sensormodule.8_sony_imx616_full.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.tuned.lsi_gc5035.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.tuned.lsi_gc5035_macro.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.tuned.lsi_s5k3l6.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.tuned.sony_imx616.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/com.samsung.tuned.sony_imx682.bin` | m51 | Samsung | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/f_dual_calibration.bin` | m51 | — | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/uw_dual_calibration.bin` | m51 | — | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib/camera/w_dual_calibration.bin` | m51 | — | Camera data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/lib64/camera/com.samsung.sensormodule.0_sony_imx682.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.sensormodule.1_sony_imx616.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.sensormodule.2_lsi_s5k3l6.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.sensormodule.3_lsi_gc5035.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.sensormodule.4_lsi_gc5035_macro.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.sensormodule.8_sony_imx616_full.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.tuned.lsi_gc5035.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.tuned.lsi_gc5035_macro.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.tuned.lsi_s5k3l6.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.tuned.sony_imx616.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/lib64/camera/com.samsung.tuned.sony_imx682.bin` | m51 | Samsung | Empty stub .so generated at build time (sensor-module/tuning placeholder). Generated empty stub (DUMMY_SHARED_LIB) — no real code shipped; build system creates an empty .so so the linker is satisfied. | Nothing to modify — the stub is generated; the real tuning data lives in the matching .bin. |
| `vendor/etc/nfc/sec_s3nrn4v_hwreg.bin` | m51 | Samsung | NFC (Firmware) data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/nfc/sec_s3nrn4v_swreg.bin` | m51 | Samsung | NFC (Firmware) data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/nfc/sec_s3nrn4v_firmware.bin` | m51 | Samsung | NFC (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/default_sensors.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/lito_mmc5603x_0.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/lito_mmc5603x_1.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/lito_mmc5603x_2.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/lito_mmc5603x_3.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/lsm6dsm_0.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sdmmagpie_lsm6dsm_0.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sdmmagpie_power_0.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sdmmagpie_stk3a6x_0.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sdmmagpie_stk3a9x_0.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_amd.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_amd_sw_disabled.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_amd_sw_enabled.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_aont.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_ccd.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_cm.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_dae.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_diag_filter.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_fmv.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_fmv_legacy.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_geomag_rv.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_gyro_cal.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_hw_revision.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_mag_cal.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_rmd.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_rotv.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_smd.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_tilt.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_tilt_sw_disabled.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/sns_tilt_sw_enabled.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/stk3a6x_0.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sensors/config/stk3a9x_0.json` | m51 | — | Sensors configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.qti.adsprpc-sscrpc-service.rc` | a71-common | Qualcomm | ADSP configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/acdbdata/adsp_avs_config.acdb` | a71-common | — | Audio calibration database (ACDB) — tuning data for the audio path. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/android.hardware.bluetooth@1.0-service-qti.rc` | a71-common | Qualcomm | Bluetooth configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/a2dpsink_audio_policy_configuration.xml` | a71-common | — | Bluetooth (A2DPSINK) configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/apbtfw11.tlv` | a71-common | — | Bluetooth (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/apnv11.bin` | a71-common | — | Bluetooth (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/CAMERA_ICP.elf` | a71-common | — | Camera (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/Data.msc` | a71-common | — | Camera (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/dax_param.bin` | a71-common | — | Camera (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.qti.hardware.capabilityconfigstore@1.0-service.rc` | a71-common | Qualcomm | Configstore configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.display.color@1.0-service.rc` | a71-common | — | Display Postprocessing configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/android.hardware.drm@1.3-service.clearkey.rc` | a71-common | — | DRM configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/android.hardware.drm@1.3-service.widevine.rc` | a71-common | Google/Widevine | DRM configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/vintf/manifest/manifest_android.hardware.drm@1.3-service.clearkey.xml` | a71-common | — | DRM configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/vintf/manifest/manifest_android.hardware.drm@1.3-service.widevine.xml` | a71-common | Google/Widevine | DRM configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.qti.cdsprpc-service.rc` | a71-common | Qualcomm | DSP configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.qti.hardware.dsp@1.0-service.rc` | a71-common | Qualcomm | DSP configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/android.hardware.gnss@2.1-service-qti.rc` | a71-common | Qualcomm | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/vintf/manifest/android.hardware.gnss@2.1-service-qti.xml` | a71-common | Qualcomm | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/floating_feature.xml` | a71-common | — | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/flp.conf` | a71-common | — | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/gnss_antenna_info.conf` | a71-common | — | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/gpfspath_oem_config.xml` | a71-common | — | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/gps.conf` | a71-common | — | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/izat.conf` | a71-common | — | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/lowi.conf` | a71-common | — | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sap.conf` | a71-common | — | GNSS configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/a618_gmu.bin` | a71-common | — | Graphics (Adreno firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/a630_gmu.bin` | a71-common | — | Graphics (Adreno firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/a630_sqe.fw` | a71-common | — | Graphics (Adreno firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/ipa_fws.b00` | a71-common | Qualcomm | IPA (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/ipa_fws.b01` | a71-common | Qualcomm | IPA (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/ipa_fws.b02` | a71-common | Qualcomm | IPA (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/ipa_fws.b03` | a71-common | Qualcomm | IPA (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/ipa_fws.b04` | a71-common | Qualcomm | IPA (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/ipa_fws.elf` | a71-common | Qualcomm | IPA (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/ipa_fws.mdt` | a71-common | Qualcomm | IPA (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/lm/AdaptLaunchFeature.xml` | a71-common | — | Machine Learning configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/hyper/config_chipset.json` | a71-common | Qualcomm | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/hyper/config_hyper_permission.json` | a71-common | — | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/hyper/config_vendor.json` | a71-common | — | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/init.qti.qcv.rc` | a71-common | Qualcomm | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.qti.rmt_storage.rc` | a71-common | Qualcomm | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.qti.tftp.rc` | a71-common | Qualcomm | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/ssg/ta_config.json` | a71-common | — | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/ssg/tz_whitelist.json` | a71-common | — | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/str/str_preference_data.dat` | a71-common | — | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/mercury.json` | a71-common | — | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/msm_irqbalance.conf` | a71-common | — | Qualcomm MSM Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sec_config` | a71-common | Samsung | Qualcomm MSM Interface data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/sec_config_oem` | a71-common | Samsung | Qualcomm MSM Interface data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/data/dsi_config.xml` | a71-common | — | RIL configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/data/netmgr_config.xml` | a71-common | — | RIL configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/dataadpl.rc` | a71-common | — | RIL configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/netmgrd.rc` | a71-common | — | RIL configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/locale/plmn_delta_zh-rCN.bin` | a71-common | — | RIL data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/locale/plmn_delta_zh-rHK.bin` | a71-common | — | RIL data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/locale/plmn_delta_zh-rTW.bin` | a71-common | — | RIL data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/mtu-conf.xml` | a71-common | — | RIL configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/plmn_delta.bin` | a71-common | — | RIL data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/plmn_delta_attaio.bin` | a71-common | — | RIL data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/plmn_delta_hktw.bin` | a71-common | — | RIL data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/plmn_delta_usagsm.bin` | a71-common | — | RIL data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/plmn_se13.bin` | a71-common | — | RIL data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/seccomp_policy/codec2.vendor.ext.policy` | a71-common | — | Seccomp Policy configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/seccomp_policy/mediacodec.policy` | a71-common | — | Seccomp Policy configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/seccomp_policy/mediaextractor_sec.policy` | a71-common | Samsung | Seccomp Policy configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/seccomp_policy/samsung.software.media.c2-base-policy` | a71-common | Samsung | Seccomp Policy data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/seccomp_policy/samsung.software.media.c2-ext-policy` | a71-common | Samsung | Seccomp Policy data file. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/seccomp_policy/vendor.qti.hardware.dsp.policy` | a71-common | Qualcomm | Seccomp Policy configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/init_thermal-engine.rc` | a71-common | — | Thermal configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.samsung.hardware.thermal@1.0-service.rc` | a71-common | Samsung | Thermal configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/thermal-engine.conf` | a71-common | — | Thermal configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/init.time_daemon.rc` | a71-common | — | Time configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/qseecomd.rc` | a71-common | — | TrustZone configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.qti.hardware.qseecom@1.0-service.rc` | a71-common | Qualcomm | TrustZone configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vendor.qti.hardware.tui_comm@1.0-service-qti.rc` | a71-common | Qualcomm | Trusted User Interface configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/configstore/vpp.configstore.xml` | a71-common | — | VPP configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/etc/init/vppservice.rc` | a71-common | — | VPP configuration file (text data). | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/wlan/qca_cld/bdwlan.bin` | a71-common | Qualcomm | WiFI (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/wlan/qca_cld/grippower.info` | a71-common | Qualcomm | WiFI (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |
| `vendor/firmware/wlan/qca_cld/regdb.bin` | a71-common | Qualcomm | WiFI (Firmware) firmware blob. | Edit the file as data (text configs directly; binary .acdb/.bin only via re-extraction or vendor tooling). |

## Method + verification

- **Pins checked first:** both vendor commits exist via the GitHub API
  (`a71-devs/android_vendor_samsung_m51` @ `de409289` → 200;
  `android_vendor_samsung_a71-common` @ `407f21e5` → 200).
- **Source of truth correction:** `proprietary-files.txt` does **not**
  live in the vendor repos — it lives in the *device* repos
  (`android_device_samsung_m51` @ `55df7b4a`,
  `android_device_samsung_a71-common` @ `48e5e36e`). A raw fetch of
  `proprietary-files.txt` from either *vendor* repo 404s. The
  manifest's count method ("non-empty, non-`#` lines in
  proprietary-files.txt at the pinned commits") is otherwise correct.
- **Counts reconciled exactly:** m51 `180`, a71-common `733`,
  total **913** — matches `trees/manifest.json`. No duplicates in
  either list (checked after stripping `:dst`, `;flags`, `|hashes`).
  Flags seen: `DUMMY_SHARED_LIB` ×11 (m51), `DISABLE_CHECKELF` ×8
  (m51) + ×7 (common), `SYMLINK=` ×6 (common, Adreno EGL libs —
  symlinks to the real blob, counted with their target's bucket),
  `FIX_SONAME` ×1, `MODULE_SUFFIX` ×2.
- **Bucket A** from `common.mk` + `m51/device.mk` at the pinned
  commits (full `PRODUCT_PACKAGES` list read live), cross-checked
  against the a71-common git tree (recursive, 370 paths) for the
  in-tree sources.
- **Bucket B** is deliberately strict: a replacement is listed only if
  the open component verifiably exists and is linked (LLVM libc++,
  tinyxml2, nanopb, QCBOR, libxml2, AOSP libeffects — all link-checked
  2026-11-24; GrapheneOS Camera, TrebleDroid, LineageOS hardware repos
  also 200). Everything else that *looks* replaceable is in C with the
  reason in § Honest limits.
- **No cloning, no API hammering:** all reads via raw.githubusercontent
  + a handful of API calls; no git operations (per the Phase 0
  execution-risk note).
- **Classification script:** `/tmp/classify_blobs.py` (rules +
  generated CSV `/tmp/blob_audit_rows.csv`, 913 rows). Rules: D by
  extension/path (`vendor/firmware/`, `vendor/etc/`, `.bin/.elf/.acdb/
  .xml/.conf/.json/.dat/.rc/.policy/.txt/.tlv/.fw/.mdt/.qwsp/.msc`)
  + `DUMMY_SHARED_LIB`; B by exact basename allow-list (5 open libs,
  13 audio-effect names); everything else C. Vendor attribution by
  path/name prefix (Samsung / Qualcomm / ArcSoft / EgisTec / Goodix /
  Synaptics / Sony / GalaxyCore / Google-Widevine); "—" where the
  path does not identify a vendor.

## Honest limits — what "modify everything" cannot mean

- **Decompiling is not source.** Ghidra/IDA on `libsec-ril.so` gives
  assembly + rough pseudo-C. You can read it, find constants and
  patch a byte or two — you cannot recover the original source, the
  build system, or the comments, and you cannot rebuild the library.
- **The modem is a black box twice over.** `libsec-ril.so` talks to
  the modem firmware, which is itself closed and runs on a separate
  processor. There is no open Samsung RIL. VoLTE/IMS has no AOSP
  equivalent (phh Floss IMS is a partial, per-carrier bridge with no
  emergency-call implementation — see reverse-engineering.md §4).
- **The GPU userspace has an open path, but it is not a swap.**
  Freedreno/Turnip (Mesa, <https://gitlab.freedesktop.org/mesa/mesa>,
  verified live) supports Adreno 618-class hardware in principle, but
  wiring Mesa into this vendor image (kernel DRM/MSM + userspace
  EGL/GLES/Vulkan + gralloc) is a bring-up project of its own, not a
  blob replacement. Counted as C, flagged here as the long-shot path.
- **The camera HAL has no open replacement.** GCam / GrapheneOS
  Camera ([GrapheneOS/Camera](https://github.com/GrapheneOS/Camera),
  verified live) replace the camera *app*. The HAL underneath — CamX
  nodes, Samsung sensor libs, ArcSoft, remosaic, EIS — stays blob, or
  there is no photo at all. Samsung's camera *features* (bokeh, HDR,
  remosaic, EIS v2/v3) have no open equivalent and are lost if the
  blobs are dropped.
- **Widevine L1 is gone on unlock** (L1→L3, 480p streaming) — no
  bridge exists, and the Widevine libs are binary-only.
- **Knox is permanently lost** on unlock. Nothing in this audit
  restores it.
- **The source-built services still call blobs.** Bucket A is real
  leverage (the service logic is ours), but e.g. the fingerprint
  service is source while the Egis/Goodix sensor libraries it calls
  are not. "We have the source for fingerprint" would be an
  overstatement — we have the source for the *service*.
- **Re-extraction does not create source.** Pulling fresh blobs from
  M515FXXU6DXJ2 (the blob-refresh plan) gives newer *binaries*, not
  source. It is still worth doing for the fingerprint string + any
  HAL fixes, but it does not move a single entry from C to B.

## What this changes in the port plan

Nothing structural — it confirms the plan's shape (port-plan.md L1–L6)
and sharpens two items:

1. **Bucket B is the only "delete the blob" work: 30 files**, all in
   a71-common, all audio effects + 5 open-library copies. Cheap, safe,
   do it when the trees are first built.
2. **The shim list is the real modification surface for C.** The tree
   already ships three shims (`libsensorndkbridge`,
   `libshim_sensorndkbridge`, `libcrypto_shim.vendor`); every future
   C-blob modification should start by asking "can this be a shim?"
   before "can this be a binary patch?".

## Credits / sources

- a71-devs device + vendor trees (lineage-22.2, 2025-04-29) — the
  inventory itself.
- LineageOS (`android_hardware_samsung`, `android_hardware_qcom_audio`,
  `android_hardware_qcom_display`) — the source-built HALs.
- AOSP (frameworks/av libeffects, hardware/interfaces) — audio
  effects + HAL services.
- LLVM (libc++), tinyxml2, nanopb, QCBOR, libxml2, OpenCV — the open
  libraries whose prebuilt copies appear in the lists.
- Mesa / Freedreno / Turnip — the long-shot open GPU path.
- GrapheneOS Camera, phhusson/treble_experimentations — camera-app and
  shim references.
