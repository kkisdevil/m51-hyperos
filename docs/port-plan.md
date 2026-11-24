# HyperOS port plan for the Galaxy M51 — device-specific rebuild

Date: 2026-11-24. Companion file:
[reverse-engineering.md](reverse-engineering.md) (device-tree audit, HyperOS
structure, the 24-row vendor gap table). This plan turns that gap map into
ordered work. Status: **phase 1 complete (this plan). No code written, nothing
flashed, no build triggered.**

## 0. Goal and non-goals

**Goal:** a device-specific HyperOS build for the Galaxy M51 (SM-M515F) that
boots to the home screen, keeps calls/data working, and fixes the GSI's
known bugs per source code — by remodifying the system, applying patches,
and building bridges/translation layers where the m51 vendor does not meet
HyperOS. HyperOS 2 (Android 15) first; HyperOS 3 (Android 16) is a separate,
later track.

**Non-goals:** a from-source Xiaomi build (there is no m51 Xiaomi source to
build from); a daily driver on day one; VoLTE on every Indian carrier on day
one; SELinux enforcing on day one; Xiaomi Camera; Widevine L1; Knox features.
Each of these is listed honestly in §5 rather than promised.

## 1. Architecture — how the rebuild goes together

The port is a stack of layers. Each layer is owned by a different repo/tree,
and a failure in one layer is debugged in that layer only.

```text
┌─────────────────────────────────────────────────────────────────┐
│ L6  Xiaomi framework patches (smali)                            │
│     miui-services.jar, telephony, account, theme, camera-ATMs   │
│     Files: port/patches/framework/  (A03-style, first-failure)  │
├─────────────────────────────────────────────────────────────────┤
│ L5  m51 RRO overlay (vendor_hardware_overlay)                   │
│     status bar, hole-punch, brightness, AOD, power profile      │
│     Files: port/overlay/  (A54 overlay as template)             │
├─────────────────────────────────────────────────────────────────┤
│ L4  HAL bridge layer (shims / wrappers)                         │
│     VNDKLite config, libsensorndkbridge, audio sec policy,      │
│     SehRadio flag, keymint override, Codec2 seccomp fix         │
│     Files: port/bridges/  (TrebleDroid + a71-common pieces)     │
├─────────────────────────────────────────────────────────────────┤
│ L3  System image (base)                                         │
│     Qualcomm-source Mystic HyperOS 2 GSI (gold, Android 15)     │
│     Files: fetched by scripts/fetch-gsi.sh (never committed)    │
├─────────────────────────────────────────────────────────────────┤
│ L2  Device tree + vendor (Samsung side, taken over)             │
│     forked a71-devs m51 + a71-common @ lineage-22.2,            │
│     vendor blobs re-extracted from M515FXXU6DXJ2                │
│     Files: device/samsung/m51, device/samsung/a71-common,       │
│            vendor/samsung/m51, vendor/samsung/a71-common        │
├─────────────────────────────────────────────────────────────────┤
│ L1  Kernel                                                      │
│     crdroidandroid/android_kernel_samsung_sm7150                │
│     4.14.357-openela + permissive boot image                    │
│     Files: kernel/samsung/sm7150 (fork)                         │
└─────────────────────────────────────────────────────────────────┘
     Boot chain: bootloader → kernel (L1) → vendor HALs (L2/L4)
                 → system (L3) + overlays (L5) + patches (L6)
```

Design rules (from the reverse-engineering):

1. **Qualcomm-source GSI only.** A MediaTek-source GSI drags in MTK
   telephony/camera jars that do not exist on any Samsung and forces the
   whole MTK RIL/ATMs shim chain. A Qualcomm-source GSI avoids it.
2. **Never flash Xiaomi's vendor.** The Treble contract: Samsung vendor
   stays, Xiaomi system goes on top. XMAPort's partition model is the
   reference for which partitions move and which stay — but XMAPort itself
   cannot run on Samsung (Xiaomi→Xiaomi only).
3. **First-failure triage, A03-style.** Fix one boot blocker at a time in
   logcat order (lights NPE → RIL → SIM power-state → camera ATMs → account
   MTD). Never batch-guess fixes.
4. **Minimal, scoped patches.** Each smali shim does the smallest thing that
   unblocks boot or a feature, scoped to the Xiaomi UID/package that needs
   it. Do not fake authentication and do not globally disable signature
   checks (A03 scoped its AccountManager hook to `com.xiaomi` / UID 1000
   only).
5. **Permissive first, enforcing later.** SELinux enforcing is a separate
   bring-up project (Phase 4), not a Phase 1 patch.
6. **Drop what cannot be bridged, say so.** Xiaomi Camera is dropped in
   favour of GCam/Lineage camera; setup wizard is bypassed, not fixed;
   VoLTE goes through Floss IMS per carrier, not through Samsung's IMS.

## 2. Base selection (decided in phase 1)

| Choice | Decision | Reason |
|---|---|---|
| Target HyperOS | **HyperOS 2 (Android 15)**, Mystic `gold` build | FCM 6 is inside Android 15's support span; smallest system↔vendor gap; A71 precedent is HyperOS 2 |
| GSI source | **Qualcomm-source Mystic GSI** (`gold`, OS2.x) | Avoids MTK telephony/camera jars |
| Device tree base | Fork `a71-devs/android_device_samsung_m51` + `a71-common` @ `lineage-22.2` | Matches HyperOS 2 / Android 15; the frozen branch the trees were left on |
| Kernel base | `crdroidandroid/android_kernel_samsung_sm7150`, **4.14.357-openela** | Only actively maintained SM7150 kernel (pushed 2026-11-22); newer than LOS 4.14.336 |
| Vendor blobs | Re-extract from stock **M515FXXU6DXJ2** (latest) via the trees' `extract-files.py` | a71-devs blobs are Android 12-era and 16 months stale; no TheMuppets m51 mirror exists |
| Cross-check | Live LineageOS a71 `lineage-23.x` trees | The m51 repos are an unmaintained snapshot; A71 is where the fixes land |
| SELinux | **Permissive** (Permissiver v5 boot image) | No published enforcing HyperOS-on-Samsung policy exists |

## 3. Ordered work phases

### Phase 0 — Tree takeover + blob refresh (desk work, no device needed)

**Phase 0 status — audit done 2026-11-24 (see
[tree-takeover.md](tree-takeover.md) + `trees/manifest.json`):**
trees pinned at `lineage-22.2` — m51 `55df7b4a`, a71-common
`48e5e36e`, a71 kernel `81831f0c` (4.14.336), vendor m51
`de409289`, vendor a71-common `407f21e5`; crDroid kernel `16.0`
`4d83f24b` (4.14.357-openela, pushed 2026-11-22). Two corrections
to reverse-engineering.md §1: the code is frozen at **2025-04-29**,
not 2025-07-15 (that is only the repos' push timestamp), and the
blob inventory is **913** entries (180 + 733), not 969. One
blocker found: the crDroid kernel has **no `m51_defconfig`** and
its `build_kernel.sh` references a non-existent
`a71_eur_open_defconfig` — the defconfig assembly must be resolved
before any kernel build. Open checks: VINTF declaration for
camera/composer/sensors/power/thermal/health/vibrator/wifi/drm/
light/allocator/mapper (not in the device manifest — verify with
`check_vintf` on the first build); the `hardware/samsung/nfc`
dependency (org + pin); the stray U+200E `board-info.txt`; the
LineageOS a71 cross-check diff. **Forks not yet created; blob
re-extraction from M515FXXU6DXJ2 not started** (needs the firmware
download). No build attempted yet.

- Fork the five a71-devs repos (m51 device, a71-common, kernel, m51 vendor,
  a71-common vendor) into the project org; record the fork point
  (`lineage-22.2`, last push 2025-07-15).
- Swap the kernel to `crdroidandroid/android_kernel_samsung_sm7150`
  (4.14.357-openela); verify it builds for the m51 defconfig.
- Re-extract vendor blobs from stock M515FXXU6DXJ2 with
  `extract-files.py`; diff against the frozen blob set and record what
  changed.
- Cross-check the m51 tree against live LineageOS a71 `lineage-23.x`
  (HAL versions, sepolicy, overlays) and port the fixes that apply.
- **Exit criteria:** trees build (AOSP/Lineage) and boot to the existing
  LineageOS state; blob inventory documented; kernel version recorded.
- **Needs a real m51?** No — until the first boot test.

### Phase 1 — HyperOS 2 boots to home screen (needs a real m51)

- Pick the Qualcomm-source Mystic HyperOS 2 GSI (`gold`); verify source
  device is Snapdragon.
- Build the system image: GSI + m51 RRO overlay (from the A54 template:
  status-bar height, hole-punch, rounded corners, 60 Hz refresh, power
  profile, brightness values imported from stock framework-res) +
  VNDKLite-style config + TrebleDroid Samsung shims
  (`BOARD_ROOT_EXTRA_FOLDERS`, `sepolicy/samsung.te`).
- Flash over the latest stock vendor with a permissive boot image; DSU
  trial first, then fastbootd flash (see [install.md](install.md)).
- **First-failure triage in logcat order** (A03 order): (1) `MiuiLightsService`
  NPE → null-safe fallback in `miui-services.jar`; (2) RIL → hybrid
  `makeRil()` to generic AOSP RIL; (3) SIM power-state → `0x0B`; (4) camera
  ATMs → `adjCameraPriority()` returns without waiting; (5) account MTD →
  immediate return + CloudID→Android-ID fallback.
- Bypass the setup wizard (provision via ADB/`settings` + first-boot script).
- **Exit criteria:** boots to the HyperOS home screen; touch, display,
  Wi-Fi work; logcat has no boot-looping service.
- **Needs a real m51?** Yes — from the first DSU trial onward.

### Phase 2 — Core hardware (needs a real m51)

- **RIL/calls/data:** verify SIM detection, calls, mobile data; set
  `ro.telephony.samsung_sehradio=false` (Fold3 lesson: otherwise signal bars
  stick at 0).
- **Audio:** ship Samsung's `audio_policy_configuration_sec.xml` /
  `audio_effects_sec.xml` (restores speaker/Dolby); BT-audio HidlToAidl
  `LOG(FATAL)`→`LOG(ERROR)` fix.
- **Sensors:** reuse a71-common's `libsensorndkbridge`; map Samsung sensor
  types in the overlay.
- **Lights/brightness/flashlight:** backlight "extended brightness range" +
  "alternative backlight scale"; QS flashlight lights-HAL shim if needed.
- **Display:** composer 2.4 compat via TrebleDroid; overlay burn-in shift +
  AOD enable.
- **Power/thermal:** keep HIDL power + `thermal@2.0-service.qti`; stub ADPF;
  accept degraded throttling.
- **Health/battery:** overlay power profile; fast-charge signalling from
  Samsung's values.
- **Exit criteria:** calls + data + audio + sensors + brightness all work;
  no service crash-loops in logcat.

### Phase 3 — Camera, fingerprint, IMS (needs a real m51)

- **Camera:** drop Xiaomi Camera; ship GCam/Lineage camera as the Camera2
  client against the Samsung HIDL 2.6 provider; document which of the 4
  rear lenses are reachable.
- **Fingerprint:** TrebleDroid HIDL fingerprint adapter + re-set active
  group/user on every HAL connection (Fold3 fix); disable Xiaomi
  in-display/optical biometric UI paths; keep only the HIDL path.
- **IMS/VoLTE:** phh Floss IMS as a privileged app, configured per Indian
  carrier (Jio, then Airtel, then Vi) — carrier IMS APN + VoIP-audio-mode
  call routing (fixes the ~40 dB mic loss). Emergency calls (112) remain
  unimplemented in Floss — document this as a hard limit.
- **KeyMint:** keep the a71-common "Override Samsung keymint entry"
  manifest override.
- **Exit criteria:** camera usable via GCam; fingerprint enrols and unlocks
  across reboots; VoLTE works on at least one carrier (Jio first).

### Phase 4 — Polish + enforcing attempt (needs a real m51)

- SELinux enforcing: full audit2allow merge from live denials (Xiaomi system
  domains + Samsung vendor domains + TrebleDroid `samsung.te` /
  `qualcomm.te`); resolve neverallow conflicts. If it cannot be made
  enforcing without breaking boot, stay permissive and document why.
- HyperOS services: ThemeManager hidden-API whitelist, Find Device marked
  unavailable, Security Center degradation documented.
- OTA path: manual reflash + re-apply patches (MysticGSI `rebuild` keeps
  layout); document the update procedure.
- **Exit criteria:** a documented "what works / what doesn't" matrix from
  real device testing; enforcing or a written reason it stays permissive.

### Track H3 — HyperOS 3 (Android 16), research only, after Phase 2

- Requires HIDL→AIDL wrappers for camera, radio, biometrics, audio, power,
  GNSS and KeyMint; a frozen/optional FCM; kernel backports that do not
  exist for SM7150; and a TrebleDroid base that has had no release since
  June 2025.
- Do not start H3 until HyperOS 2 reaches Phase 2 exit criteria. The H3
  feasibility spike is: one HIDL→AIDL wrapper (vibrator — smallest) to
  prove the pattern, then decide.

## 4. Build / test loop

```text
desk:  GSI (fetch-gsi.sh) + overlay + bridges + patches
         → assemble system image (MysticGSI rebuild flow)
         → validate scripts (bash -n, shellcheck, workflow checks)
device:  DSU trial boot  →  logcat first-failure triage
         → fix in the right layer (L1–L6)  →  rebuild
         → fastbootd flash  →  feature matrix test
         → record results in docs/known-issues.md
```

- Every fix lands in exactly one layer (see §1 diagram) with a commit
  message naming the layer, the upstream file, and the logcat line that
  proved the failure.
- Every test run records: GSI build, vendor version, kernel version, what
  was tested, what worked, logcat excerpts for what did not.
- No fix is merged on the basis of "should work" — only on a device log
  or a cited precedent (A03, Fold3, TrebleDroid, A54 overlay).

## 5. What needs a real m51 — and honest limits

**Needs a real m51 (from Phase 1 onward):** DSU trial boot, fastbootd flash,
logcat triage, RIL/calls/data, audio, sensors, brightness, camera, fingerprint,
VoLTE per carrier, SELinux denial collection. None of this can be done from
GitHub Actions or a PC emulator — the vendor HALs only exist on the phone.

**Honest limits (do not promise past these):**

- **Daily driver is not guaranteed.** HyperOS 2 on m51 is an experiment
  until Phase 3 exit criteria are met; VoLTE/emergency calls are the
  hardest limit.
- **Xiaomi Camera will not work** — it needs Xiaomi camera libs + vendor
  extensions that do not exist for this HAL. GCam is the camera path.
- **Widevine falls L1→L3** (480p streaming) once the bootloader is unlocked;
  no bridge exists.
- **Knox is permanently lost** on unlock (Secure Folder, Samsung Pay, Knox
  attestation). Nothing in this port restores it.
- **No OTA updates** — updates are manual reflash + re-apply patches.
- **HyperOS 3 may never be a daily driver** on this vendor; the HIDL→AIDL
  cliff + 4.14 kernel ceiling + unmaintained TrebleDroid may cap the port at
  HyperOS 2.
- **TrebleDroid has had no release since June 2025** and the GSI scene is
  shrinking (MysticGSI still publishes, but do not assume long-term updates).
- **Play Integrity / banking apps** will fail without extra work (unlocked
  bootloader + GSI).

## 6. Repo map (where the work lives)

```text
m51-hyperos/
├── README.md, CREDITS.md, LICENSE (GPL-3.0)
├── docs/
│   ├── install.md            # full flash guide (GSI route, current)
│   ├── dsu-trial.md          # DSU trial boot (do this first)
│   ├── known-issues.md       # expected broken things + workarounds
│   ├── faq.md
│   ├── reverse-engineering.md# this file's companion: trees, HyperOS
│   │                         # structure, 24-row gap table
│   └── port-plan.md          # this file: architecture + phases
├── scripts/
│   ├── fetch-gsi.sh          # download a HyperOS GSI
│   └── verify-device.sh      # go / no-go prerequisite check
├── port/                     # (to be created in Phase 0)
│   ├── patches/framework/    # L6 smali patches (A03-style)
│   ├── overlay/              # L5 m51 RRO overlay
│   └── bridges/              # L4 HAL shims / wrappers
└── .github/workflows/        # validate + test (no firmware downloads)
```

Device trees, kernel, and vendor blobs live in their own forked repos (see
§2) — not in this repo. This repo holds the port (patches, overlay, bridges,
docs, scripts); the trees are the base it builds on.

## 7. Sources

- [reverse-engineering.md](reverse-engineering.md) — full source list
  (MysticGSI, XMAPort, A03 project, obsidian kit, AOSP FCM/VNDK docs,
  Fold3 project, TrebleDroid/phh, Droidwin, A71 threads, a71-devs trees).
- a71-devs trees: https://github.com/a71-devs/android_device_samsung_m51
  (+ a71-common, kernel, vendor — see reverse-engineering.md §1).
- crDroid SM7150 kernel:
  https://github.com/crdroidandroid/android_kernel_samsung_sm7150
- LineageOS a71 (live upstream):
  https://github.com/LineageOS/android_device_samsung_a71
