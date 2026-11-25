# Reverse Engineering — Fingerprint HAL (M51, HyperOS 2)

**Status:** RE complete (2026-11-25). Porting fix is a **2-prop overlay change + no code patch** for HyperOS 2 — but one prop's value can only be read off a booted device, so fingerprint stays unverified until first boot.

**Scope:** HyperOS 2 (MysticGSI `spring`, Android 15) on the Samsung Galaxy M51
(SM-M515F, sm7150/sm6150). HyperOS 3 notes are research-only (§3.8).

**Verdict up front**

1. The M51 fingerprint HAL is **not HIDL 2.1**. The *device manifest* declares HIDL
   fingerprint 2.1, but the service that actually runs is **AIDL
   `android.hardware.biometrics.fingerprint` v4** — a source-built service in
   LineageOS `android_hardware_samsung` (`aidl/fingerprint/`) that wraps the
   legacy Samsung C HAL (`libbauthserver.so`, a binary blob) through a thin
   `dlopen`/`dlsym` adapter. The HIDL 2.1 declaration is dead weight on
   HyperOS 2: the Android 15 framework never touches HIDL fingerprint.
2. **HyperOS 2's framework is satisfied as-is** — its compatibility matrix
   (202404) requires AIDL fingerprint **3–4**; the Samsung service provides
   v4. No TrebleDroid adapter is needed for the vendor side: AOSP 15 already
   ships `HidlToAidlSensorAdapter`, and it only runs if the sensor is HIDL —
   ours is not.
3. **The enrolment-loss fix is already structural in the service** — every new
   `Session` re-sets the active group to `/data/vendor/biometrics/fp/User_<uid>/`.
   The Fold3 framework-side fix (re-send the active group after `rild`
   restarts) is a belt-and-braces fallback, not the primary fix.
4. **The port will still show "no fingerprint hardware" unless two props are
   set** — this is the single highest-value finding:
   - `persist.vendor.sys.fp.vendor` — Xiaomi's `FingerprintServiceStubImpl`
     returns `isFpHardwareDetected() == false` when this prop is empty or
     `"none"`. **Nothing in the GSI or the m51 vendor sets it.** Fix: set it
     in the overlay/vendor.prop to the sensor vendor string — **value TBD
     from the device** (`/sys/class/fingerprint/fingerprint/vendor`).
   - `ro.hardware.fp.sideCap=true` — gates Xiaomi's power-button fingerprint
     path (`IS_POWERFP`). Not set on m51 today. Fix: set it in the overlay.
5. The missing Xiaomi extension HAL
   (`vendor.xiaomi.hardware.fingerprintextension@1.0::IXiaomiFingerprint`)
   **can never crash the service**: every call site is null-checked or
   try/catch'd and degrades to `-1` + a log line. No shim is needed for it.
6. **What cannot be known until first boot:** the sensor vendor string
   (QBT2000 is the strongest signal in the blob, but the blob carries Egis
   and Goodix code paths too); whether `libbauthserver.so` actually opens
   and talks to the TrustZone TA on this kernel; whether enrolment survives
   a reboot; whether the HIDL 2.1 manifest declaration passes `check_vintf`.

**Corrections to earlier docs (recorded here so they are not re-copied):**

- `docs/reverse-engineering.md` §3 row 5 and `docs/port-plan.md` Phase 3 say
  the m51 fingerprint is "HIDL fingerprint 2.1" and the port needs "the
  TrebleDroid HIDL fingerprint adapter". **Both are wrong as written.**
  The *manifest declaration* is HIDL 2.1, but the *running service* is AIDL
  v4; the "TrebleDroid adapter" is `HidlToAidlSensorAdapter`, which ships
  inside AOSP 15's framework and is only instantiated for HIDL sensors —
  it is a fallback, not something the port must add.
- `research/09b-arnav-ports.md` §3.1 attributes a
  `vendor.samsung.hardware.biometrics.fingerprint` **3.0** declaration to the
  vendor. That declaration comes from **Hyper371's compatibility-matrix
  precheck** (their vendor-manifest analysis), **not** from the a71-common
  device manifest, and **no such service binary exists in the frozen blob
  set** (both `proprietary-files.txt` greps are empty). The port does not
  provide it, and the HyperOS 2 framework does not ask for it.

---

## 1. The Samsung side — the fingerprint service

### 1.0 What the HAL is

A **source-built AIDL service** (Apache-2.0, LineageOS) that exposes the
AIDL biometrics interface to the framework and talks to Samsung's proprietary
sensor library through a 12-function C interface. Two layers, cleanly split:

| Layer | What it is | Licence / source |
|---|---|---|
| `android.hardware.biometrics.fingerprint-service.samsung` | AIDL service, built from source in the tree | Apache-2.0, `LineageOS/android_hardware_samsung` branch `lineage-22.2`, `aidl/fingerprint/` |
| `libbauthserver.so` (+ `libsfp_sensor.so` fallback) | The real sensor driver client — talks to the fingerprint TA in TrustZone | Binary blob, frozen vendor set, bucket C in `docs/blob-audit.md` |

The service is **bucket A** in `docs/blob-audit.md` ("source-built in tree"),
but it wraps a bucket-C blob underneath — exactly the same shape as the
audio HAL and the camera provider service. The split matters for the port:
we can rebuild and patch the service freely; the blob can only be shimmed
or worked around.

### 1.1 Where it lives

```
# In the fork we own (kkisdevil/android_hardware_samsung, lineage-22.2):
aidl/fingerprint/
├── Android.bp                  # cc_binary fingerprint-service.samsung, vendor:true
├── fingerprint.sysprop         # the 8 sysprops the service reads
├── service.cpp                 # main(): registers IFingerprint/default
├── Fingerprint.cpp/.h          # the AIDL service (232 lines)
├── Session.cpp/.h              # per-session state, the enrolment fix (465 lines)
├── LegacyHAL.cpp/.h            # dlopen/dlsym adapter to the C HAL
├── Legacy2Aidl.h               # callback translation (HAL -> AIDL)
├── CancellationSignal.cpp/.h   # cancel support
├── LockoutTracker.cpp/.h       # lockout bookkeeping
├── VendorConstants.h           # Samsung request/event codes
└── android.hardware.biometrics.fingerprint-service.samsung.xml
                                # VINTF fragment: IFingerprint/default, version 4
```

The fork was created 2026-11-24 ~20:56 IST (forked from
`LineageOS/android_hardware_samsung`, fork point `0365e8bd`); the lights
no-op commit (`e7968ab`) is in the same fork. The fingerprint service is
already in the fork — **no new fork is needed for fingerprint**.

**Device-tree wiring (a71-common + m51):**

| File | What it does |
|---|---|
| `device/samsung/a71-common/manifest.xml` | Declares HIDL `android.hardware.biometrics.fingerprint` **2.1**, `IBiometricsFingerprint/default` — stale, see §1.5 |
| `device/samsung/a71-common/common.mk` | Pulls in `android.hardware.biometrics.fingerprint-service.samsung` (the AIDL service) |
| `device/samsung/a71-common/init/fingerprint_common.rc` | chmod/chown sensor nodes + sysfs, mkdir data dirs |
| `device/samsung/a71-common/init/init.fingerprint.rc` | Same body as above, plus `on init: write /sys/class/sec/tsp/cmd "fod_enable,1,1,0"` |
| `device/samsung/a71-common/sepolicy/vendor/hal_fingerprint_default.te` | `biometrics_vendor_data_file`, `efs`, `fp_sensor_device`, `sysfs_fpc`, `tee_device`, `set_prop(hal_fingerprint_default, vendor_fingerprint_prop)` |
| `device/samsung/m51/vendor.prop` | `ro.vendor.fingerprint.type=side`, `ro.vendor.fingerprint.sensor_location=1080\|800\|350` — exactly the props the service reads |
| `device/samsung/m51/overlay/.../dimens.xml` | `physical_fingerprint_sensor_center_screen_location_x` = 1080px, y = power-button centre |
| `device/samsung/m51/init.m51.rc` | chown `system:radio` on `/sys/class/fingerprint/fingerprint/*` |

### 1.2 The AIDL service — function map

**`Fingerprint.cpp`** (the AIDL service object, `IFingerprint/default`):

- `getSensorProps()` — returns a single sensor: **id 0, SENSOR_STRENGTH
  STRONG, max enrollments (default 4, overridable), sensor type read from
  `ro.vendor.fingerprint.type`** (`"side"` → `POWER_BUTTON`,
  `"udfps"` → `UNDER_DISPLAY_OPTICAL`, anything else → `REAR`).
  Sensor location is parsed from `ro.vendor.fingerprint.sensor_location`
  as `x|y|radius|display` — on m51 that is **1080|800|350**, i.e. the right
  edge of the 1080px-wide screen, 800px down, radius 350. This is the
  location the framework (and therefore the lockscreen UI) actually uses;
  the overlay `dimens.xml` value agrees with it.
- `createSession()` — enforces a **single open session** (`CHECK(mSession
  == nullptr)`) and `linkToDeath` on the client, so a dead client cannot
  leave the HAL wedged.
- Gestures — if `ro.vendor.fingerprint.supports_gestures` is true, the
  service opens a uinput device called **`uinput-sec-fp`** and injects
  `KEY_UP`/`KEY_DOWN` for swipe gestures. On m51 the prop is **not set**,
  so gestures are off and no uinput device is created. (Correct — a side
  sensor has no swipe surface.)
- `cancel()` / `onClientDeath()` — teardown paths.

**`Session.cpp`** (465 lines — **the file that carries the enrolment fix**):

- **Constructor (lines 37–48) — the fix.** Every new session calls
  `ss_fingerprint_set_active_group(userId, FINGERPRINT_DATA_DIR)` where
  `FINGERPRINT_DATA_DIR` is `"/data/vendor/biometrics/fp/User_%d/"`
  (`Session.h:17`). The active group is therefore re-asserted on **every**
  HAL connection, not just at first enrolment. This is the same fix the
  Fold3 lineage tree documents ("Framework sets the active group on every
  HAL connection") — except here it lives in the HAL itself, so it holds
  even if the framework never re-sends it.
- `generateChallenge()` → `ss_fingerprint_pre_enroll()`; `revokeChallenge()`
  → `ss_fingerprint_post_enroll()`.
- `enroll()` — if `ro.vendor.fingerprint.force_calibrate` is set, runs
  `SEM_REQUEST_FORCE_CBGE` (calibration) first.
- `authenticate()` / `detectInteraction()` / `detectFinger()` —
  authentication flows; `detectFinger` is the "finger down" probe.
- `enumerateEnrollments()` — first tries `ss_fingerprint_enumerate()`; if
  the blob does not implement it, falls back to **reading the data dir**:
  files matching `User_<uid>_<fid>tmpl.dat` are treated as enrolled
  templates. (So the data dir layout is load-bearing — see §1.4.)
- `removeEnrollments()` / `getAuthenticatorId()` /
  `invalidateAuthenticatorId()` — `ss_fingerprint_get_auth_id()`.
- `resetLockout()` — `ss_fingerprint_lockout_reset()`.
- `onPointerDown()` / `onPointerUp()` — only if
  `ro.vendor.fingerprint.request_touch_event` is set, forwards
  `SEM_REQUEST_TOUCH_EVENT` to the blob.
- `close()` — `ss_fingerprint_close()`.

**`LegacyHAL.cpp`** — the adapter. `dlopen`s **`libbauthserver.so`**,
falling back to **`libsfp_sensor.so`** if the first is absent, then
`dlsym`s the 12 `ss_fingerprint_*` entry points. If a symbol is missing
the adapter logs and the corresponding call becomes a no-op — the service
degrades instead of crashing.

**`VendorConstants.h`** — Samsung request codes (`SET_ACTIVE_GROUP` 8,
`GET_USERIDS` 12, `UPDATE_SID` 10, `ENROLL_SESSION` 1002, …) and SEM event
codes. The in-display/optical codes (`0x3F0`–`0x3FA`, `FIDO` 9,
navigation 15–17) are **inert on m51** — there is no under-display sensor
and the service never sends them for a `POWER_BUTTON` sensor.

**`fingerprint.sysprop`** — the 8 props the service reads (all
`ro.vendor.fingerprint.*`): `type`, `max_enrollments`,
`supports_gestures`, `sensor_location`, `force_calibrate`,
`request_touch_event`, `uses_percentage_samples`,
`cancel_on_enroll_completion`. The m51 tree sets only the two that matter
(`type=side`, `sensor_location=1080|800|350`); the rest default off.

### 1.3 The init + sepolicy contract

`init/fingerprint_common.rc` (and the near-identical
`init/init.fingerprint.rc`) do the device setup the service assumes:

```
# Sensor device nodes (one per vendor — the blob picks the one that exists):
chmod 0660 /dev/esfp0          # Egis
chmod 0660 /dev/goodix_fp      # Goodix
chmod 0660 /dev/qbt2000_fd /dev/qbt2000_ipc /dev/qbt2000_spi   # Qualcomm QBT2000
# Sysfs (all chown system:radio):
/sys/class/fingerprint/fingerprint/{type_check,name,vendor,adm,bfs_values,
    position,cbgecnt,intcnt,resetcnt,wuhbtest,rb}
# Data dirs:
mkdir /data/vendor/misc/qti_fp/{snrTest,qbt2000}
mkdir /data/vendor/biometrics /data/vendor/fpSnrTest /efs/biometrics/meta
```

`init.fingerprint.rc` additionally writes `fod_enable,1,1,0` to
`/sys/class/sec/tsp/cmd` at init — a leftover for under-display devices;
harmless on m51 (the node exists, the write is a no-op for a side sensor).

`sepolicy/vendor/hal_fingerprint_default.te` grants the service
`biometrics_vendor_data_file`, `efs`, `firmware`, `fp_sensor_device`,
`sysfs_fpc`, `tee_device`, `vendor_data_file` and
`set_prop(hal_fingerprint_default, vendor_fingerprint_prop)`. The
`tee_device` grant is the important one: the blob talks to the fingerprint
TA through the TEE driver, and the service needs that allow-rule.

### 1.4 The sensor blob — `libbauthserver.so` (verified at symbol level)

Fetched from `a71-devs/android_vendor_samsung_m51` branch `lineage-22.2`,
`proprietary/vendor/lib64/libbauthserver.so` — **461,768 bytes, AArch64,
stripped**. Verified against the live file:

- **Exports all 12 `ss_fingerprint_*` symbols** the adapter `dlsym`s
  (`ss_fingerprint_open`, `..._close`, `..._pre_enroll`,
  `..._post_enroll`, `..._enroll`, `..._authenticate`,
  `..._cancel`, `..._enumerate`, `..._remove`, `..._set_active_group`,
  `..._get_auth_id`, `..._lockout_reset` — plus the `sem_*` helpers).
- **All NEEDED libraries are in the frozen blob set**
  (`proprietary-files.txt` lines 135–152): `libbauthtzcommon.so`,
  `libsynaFpSensorTestNwd.so`, `libegis_fp_normal_sensor_test.so`,
  `libgf_in_system_lib.so`, `libqfp_sensortest.so`.
- **Strings show three sensor vendors in one blob** — Egis (`egisFpDevice*`,
  ET510), Goodix (`/dev/goodix_fp`), and Qualcomm **QBT2000**
  (`/dev/qbt2000_fd`, `/dev/qbt2000_ipc`, `fp_qbt1000_normalscan.txt`).
  The blob is a generic multi-vendor build; **which sensor the m51
  actually has is not determinable from strings alone**.
- **The blob sets no properties.** `libbauthserver.so` contains **no
  `persist.*` property references at all** — it cannot be the source of
  `persist.vendor.sys.fp.vendor`. That prop must come from the port.
- **Strongest single signal: QBT2000.** The QBT2000 device nodes are the
  ones the init rc creates with the most specific setup (fd/ipc/spi +
  `qbt2000` data dirs), and the QBT2000 strings are the most numerous.
  Egis ET510 is the second candidate. **Settle it on device:**
  `cat /sys/class/fingerprint/fingerprint/vendor` and `.../name`.

### 1.5 The HIDL 2.1 declaration — stale, but harmless for now

The a71-common device manifest declares HIDL fingerprint **2.1**
(`IBiometricsFingerprint/default`). Nothing in the tree ships a HIDL 2.1
service binary — the service that exists is the AIDL v4 one. On HyperOS 2
the framework never asks for the HIDL service (see §2.1), so the
declaration is inert. **First-build check:** run `check_vintf` on the
assembled image; if it flags the unfulfilled HIDL declaration, delete the
entry from the manifest. Do not delete it pre-emptively — it is also the
only thing that would make the `HidlToAidlSensorAdapter` path (§2.2)
available if the AIDL service ever fails to start.

---

## 2. What the GSI expects — the framework contract

### 2.0 What was read, and how

The spring GSI `system.img` (6,232,481,792 bytes, ext4, verified MD5
`3e6337d1dd850ae2d0f7d067f8dd191c`) was read with `debugfs` (no loop
devices on this VM). `services.jar` (32,421,449 B) and `miui-services.jar`
(9,955,131 B) were extracted and disassembled with **baksmali 2.5.2**
(OpenJDK 25; jars fetched fresh from Maven Central). All class/method
citations below are from that disassembly. Working files are in
`/tmp/re-fp/` (ephemeral — re-fetch + re-disassemble if gone, ~15 min).

### 2.1 The framework is AIDL-only

**`FingerprintService`** (`services.jar`,
`com/android/server/biometrics/sensors/fingerprint/FingerprintService.smali`,
1,435 lines) uses only the AIDL path:

- `FingerprintProvider` → `IFingerprint.DESCRIPTOR` →
  `ServiceManager.waitForDeclaredService("android.hardware.biometrics.fingerprint.IFingerprint/default")`
  (`FingerprintService.smali:929`) → `getSensorProps()`.
- **Zero references to HIDL `IBiometricsFingerprint`** anywhere in
  `FingerprintService.smali`. The HIDL V2_1/V2_2/V2_3 classes present in
  `classes.dex` are unused legacy stubs.
- **Failure mode if the AIDL service is absent:** the provider function
  logs `"Unable to get declared service"` and returns null — fingerprint
  is silently absent, **no crash**. But `waitForDeclaredService` blocks
  until the declared service appears, so a HAL service that starts late
  or never comes up stalls fingerprint setup (it does not stall boot —
  the wait is on the fingerprint path, not the boot path).
- The GSI's **framework compatibility matrix (`202404`)** requires AIDL
  `android.hardware.biometrics.fingerprint` **version 3–4**, instances
  `default` + `virtual`. The Samsung service provides **v4** → the
  contract is satisfied with no shim.

**`Sensor.isHardwareDetected()`** (`aidl/Sensor.smali:1207`) gates the
sensor on two things: `ServiceManager.checkService(...)` for the AIDL
service **and** the Xiaomi stub's `isFpHardwareDetected()` (§3.4). Both
must pass before Settings shows a fingerprint option.

### 2.2 The "TrebleDroid adapter" is already in AOSP

`FingerprintProvider` (`aidl/FingerprintProvider.smali:666–688`)
instantiates `hidl/HidlToAidlSensorAdapter` **when the sensor it finds is
a HIDL one**. That is the TrebleDroid HIDL-fingerprint adapter — it ships
inside AOSP 15's framework, not as a separate TrebleDroid component, and
it is a **fallback**: it only runs if the vendor provides a HIDL
fingerprint service and no AIDL one. Our vendor provides AIDL v4
directly, so the adapter never runs. **Nothing to add, nothing to port.**

### 2.3 The Xiaomi side — the fingerprint stubs

`miui-services.jar` carries Xiaomi's fingerprint stack. The classes that
matter, and what they actually do on a non-Xiaomi device:

| Class | Role on m51 |
|---|---|
| `FingerprintServiceStubImpl` | The active stub. Stores the Xiaomi extension HAL name as a field; overrides `isFpHardwareDetected()` with the `persist.vendor.sys.fp.vendor` prop check (§3.4). |
| `FingerprintServiceInjectorStubImpl` | Wiring for the stubs; instantiates the Power/FOD/HeartRate impls. |
| `PowerFingerprintServiceStubImpl` | Side-fingerprint (power-button) support. Gated on `ro.hardware.fp.sideCap` (§3.5). |
| `FodFingerprintServiceStubImpl` | Under-display (FOD) support. Inert on m51 — `IS_FODENGINE_ENABLED` is false. |
| `HeartRateFingerprintServiceStubImpl` | Heart-rate-via-fingerprint. Not a hardware feature on m51; inert. |
| `MiuiFingerprintCloudController` | Telemetry/cloud. Reads the vendor prop for statistics only. |
| `MiFxTunnelAidl` / `MiFxTunnelHidl` | FOD tunnel to the Xiaomi extension HAL. Inert (no FOD engine). |

The base AOSP `FingerprintServiceStub.isFpHardwareDetected()` returns
**`true` unconditionally** (`FingerprintServiceStub.smali:919–925`). The
prop-gating in §3.4 is **purely Xiaomi's addition** — on AOSP the sensor
would always report detected; on HyperOS it reports detected only if the
prop is set.

### 3.4 The two props that decide everything

**Prop 1 — `persist.vendor.sys.fp.vendor`** (the hardware-detection gate).

`FingerprintServiceStubImpl.isFpHardwareDetected()`
(`FingerprintServiceStubImpl.smali:730`) returns true only if this prop
is **non-empty and not `"none"`**. The AOSP `aidl/Sensor` and
`aidl/FingerprintProvider` gate the sensor on it (§2.1). **Nothing in
the GSI sets this prop** (no `SystemProperties.set` for it in either
smali tree) and **nothing in the m51 vendor sets it** (the blob contains
no property writes, §1.4; the device tree greps are empty). **As the
port stands today, HyperOS would report "no fingerprint hardware" even
with a perfectly working HAL.** Fix: set it in the overlay/vendor.prop
to the sensor vendor string — **value TBD from the device**
(`/sys/class/fingerprint/fingerprint/vendor`). Any non-empty value
unblocks detection; the honest value is the one the sysfs node reports.

**Prop 2 — `ro.hardware.fp.sideCap`** (the power-fingerprint gate).

`PowerFingerprintServiceStubImpl`'s constructor
(`PowerFingerprintServiceStubImpl.smali:137`) reads it:
`IS_POWERFP = SystemProperties.getBoolean("ro.hardware.fp.sideCap", false)`.
The m51 tree does **not** set it (it sets `ro.vendor.fingerprint.type=side`,
`persist.vendor.fingerprint.type=side`, `persist.sys.fp.side=true`,
`ro.hardware.fingerprint=m51` — none of which Xiaomi reads). Fix: set
`ro.hardware.fp.sideCap=true` in the overlay. The prop is also read by
`MiuiPhoneWindowManager`, `BaseMiuiPhoneWindowManager`, `PowerKeyRule`,
display handlers and bigdata classes — setting it declares "side
capacitive sensor" to the whole Xiaomi framework, which is exactly what
the m51 is.

Related Xiaomi reads (all default-safe on m51):

- `IS_SUPPORT_FINGERPRINT_TAP` — from `FeatureParser`
  `is_support_fingerprint_tap` (`PowerFingerprintServiceStubImpl.smali:148`).
  Default false on a GSI with no Xiaomi feature XML. Governs the
  double-tap-side-fingerprint flow; leave default.
- `IS_FOLD` — from `persist.sys.muiltdisplay_type`. Not set on m51; false.
- `mSideFpUnlockType` — default `-1`. `DOUBLE_TAP_SIDE_FP` is the Settings
  key `fingerprint_double_tap`.
- `FINGERPRINT_CMD_LOCKOUT_MODE` = `0xc` (12) — the ext-command number the
  power stub sends when the lockout mode changes (§3.5).

### 3.5 The Xiaomi extension HAL — missing, and provably harmless

`vendor.xiaomi.hardware.fingerprintextension@1.0::IXiaomiFingerprint`
is stored as a field name in `FingerprintServiceStubImpl`
(`FingerprintServiceStubImpl.smali:74`) and nowhere else is it bound:
**nothing in the GSI provides that HAL, and nothing in the m51 vendor
does either.** The only code that touches it is
`FingerprintServiceStub.startExtCmd(cmd, param)`
(`FingerprintServiceStub.smali:249+`), which dispatches on
`mServiceVersion`:

| `mServiceVersion` | When | Behaviour when the extension HAL is absent |
|---|---|---|
| 0 | Constructor default, before any sensor is seen | Immediate return `-1` (no-op). |
| 1 | A sensor is a `HidlToAidlSensorAdapter` (HIDL sensor) | `getExtDaemon()` in try/catch (`Exception`) → logs `"getExtDaemon failed"`, returns `-1`. The latent NPE inside `getExtDaemon` (a `linkToDeath` on a null binder) is caught by that handler. |
| 2 | **No HIDL sensor found — the m51 case** (AIDL sensor) | `ServiceManager.getService("vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default")` returns null → logs `"[JAVA] Getting vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default service daemon binder failed!"`, returns `-1`. |

`mServiceVersion` is set by the stub's sensor-scan: any HIDL sensor →
1, otherwise → **2** (`FingerprintServiceStub.smali:1070–1102`). On m51
the sensor is the AIDL v4 service, so version 2 applies and the AIDL
branch runs. **Every path degrades to `-1` + a log line; none of them
can crash `system_server`.** Callers are the power stub (lockout-mode
cmd 12, in the double-tap flows) and the FOD stub — both already gated
off or inert on m51. **No shim for the extension HAL is needed.**

### 3.6 What actually happens on m51 at runtime (predicted, pre-boot)

1. `init` starts `vendor.fingerprint-default` (late_start, `user system`).
2. The Samsung AIDL service `dlopen`s `libbauthserver.so`, opens the
   sensor, registers `IFingerprint/default` v4.
3. The framework's `FingerprintProvider` finds the AIDL service,
   `getSensorProps()` returns sensor 0, STRONG, POWER_BUTTON, location
   1080|800|350.
4. `Sensor.isHardwareDetected()` checks the AIDL service (present) **and**
   the Xiaomi stub (fails today — prop unset; passes after the §5 fix).
5. Settings shows the fingerprint option; enrolment writes templates to
   `/data/vendor/biometrics/fp/User_<uid>/`; every new session re-sets
   the active group, so enrolment survives reboots.
6. The lockscreen shows a side-fingerprint affordance at the power
   button — **no under-display fingerprint UI should appear**, because
   the sensor type is `POWER_BUTTON` and the FOD engine is disabled.

### 3.7 Residual risks (Xiaomi side)

- **`ro.hardware.fp.sideCap=true` changes power-key behaviour.**
  `PowerKeyRule` and `MiuiPhoneWindowManager` read it. On Xiaomi side-fp
  devices this is the correct declaration, and the m51 is a side-fp
  device — but the exact power-key interactions (long-press, double-tap
  to launch) are only provable on a booted device. First-boot check:
  power key still locks/unlocks normally.
- **Double-tap-side-fp** (`fingerprint_double_tap`) reads a Settings
  value that defaults off; if the user ever enables it, the flow calls
  `startExtCmd(12, …)` → `-1` + log, which is a silent no-op, not a
  crash. Acceptable.
- **`MiuiFingerprintCloudController`** may log fingerprint statistics
  with an empty vendor string until the §5 prop is set. Telemetry only.

### 3.8 HyperOS 3 note (research-only)

HyperOS 3 (Android 16) is expected to require AIDL biometrics **v5**;
the Samsung service is **v4**. That is a service-bump or wrapper job on
the H3 track — **not** an H2 blocker. Verify against the H3 GSI's
compatibility matrix when that track starts (the H2 matrix, 202404,
wants 3–4).

---

## 4. The mismatch map

| # | Samsung / vendor side | HyperOS 2 expects | Status |
|---|---|---|---|
| 1 | AIDL fingerprint **v4** service | AIDL fingerprint 3–4 | ✅ Satisfied — no work |
| 2 | HIDL fingerprint 2.1 declared in device manifest | Nothing (framework is AIDL-only) | ⚠️ Stale declaration — `check_vintf` on first build; delete if flagged |
| 3 | `libbauthserver.so` (multi-vendor blob) | A sensor that opens + authenticates | ❓ Only provable on device (TA + sensor node) |
| 4 | `persist.vendor.sys.fp.vendor` — **unset everywhere** | Non-empty for `isFpHardwareDetected()` | 🔴 **Fix required (§5.1)** — value TBD from device sysfs |
| 5 | `ro.hardware.fp.sideCap` — **unset** | `true` for the power-fp path | 🔴 **Fix required (§5.2)** |
| 6 | `ro.vendor.fingerprint.type=side`, `sensor_location=1080\|800\|350` | Read by the Samsung service itself | ✅ Already in `m51/vendor.prop` |
| 7 | Xiaomi extension HAL — absent | Optional (null-safe, `-1` + log) | ✅ No work |
| 8 | Enrolment persistence | Active group re-set per session | ✅ Already in `Session.cpp` ctor |
| 9 | FOD / under-display UI | Must not appear for a side sensor | ✅ Inert (`IS_FODENGINE_ENABLED` false, sensor type `POWER_BUTTON`) |
| 10 | Sensor vendor identity | Needed for prop 4's value | ❓ Device sysfs (`vendor` + `name` nodes); QBT2000 is the leading candidate |

---

## 5. The fix (Phase 3, in order)

**5.1 Set the hardware-detection prop (REQUIRED).**
In the L5 RRO overlay / `vendor/props/fingerprint-side.prop` (already
exists — extend it):

```
# Fingerprint hardware detection (HyperOS 2, Xiaomi stub).
# Without this, HyperOS reports "no fingerprint hardware" even if the HAL works.
# Value = the sensor vendor string from /sys/class/fingerprint/fingerprint/vendor
# on a booted device (QBT2000 is the leading candidate — see docs/re-fingerprint.md §1.4).
# persist.vendor.sys.fp.vendor=<vendor string from device>
```

**5.2 Set the side-fingerprint declaration (REQUIRED).**
Same file:

```
# Side-mounted (power-button) fingerprint sensor — enables Xiaomi's power-fp path.
ro.hardware.fp.sideCap=true
```

**5.3 Keep the existing props.** `ro.vendor.fingerprint.type=side` and
`ro.vendor.fingerprint.sensor_location=1080|800|350` are already in
`m51/vendor.prop` and are exactly what the Samsung service reads. Do not
change them.

**5.4 Ship the service as-is.** No code change to
`android_hardware_samsung` `aidl/fingerprint/` is needed for HyperOS 2.
The fork already contains it; the build (Phase 1) just needs to include
`android.hardware.biometrics.fingerprint-service.samsung` and its VINTF
fragment.

**5.5 First-build verification.**
- `check_vintf` on the assembled image — decides the HIDL 2.1
  declaration's fate (§1.5).
- `lshal` / `service list` on first boot: `IFingerprint/default` present.
- `getprop persist.vendor.sys.fp.vendor` non-empty.
- `dumpsys biometric` shows sensor 0, STRONG, POWER_BUTTON.

**5.6 Belt-and-braces enrolment fix (only if first-boot logs show drops).**
If enrolment ever drops at boot (Fold3's checklist: "rarely the
enrollment can still drop at boot if the HAL crashes"), add the Fold3
framework-side fix: a boot service that re-sends the active group after
`rild` restarts. The HAL-side fix (§1.2) should already cover it — do
not add this pre-emptively.

**5.7 Do NOT do any of these:**
- Do not port the TrebleDroid HIDL adapter as a separate component —
  it is already in AOSP and does not run for an AIDL sensor (§2.2).
- Do not write a shim for the Xiaomi extension HAL — it is provably
  optional (§3.5).
- Do not set `ro.vendor.fingerprint.type` to anything other than `side`.
- Do not enable the FOD path (`IS_FODENGINE_ENABLED` must stay false) or
  the in-display SEM codes — the m51 has no under-display sensor.

---

## 6. Clean-room reconstruction

The only new code the port needs for fingerprint on HyperOS 2 is the two
props in §5.1–5.2 — there is nothing to reimplement. The reconstruction
note is therefore about **what not to rebuild**:

- **Do not reimplement the Samsung service.** It is Apache-2.0 open
  source, already in our fork, and already does the right thing
  (AIDL v4, per-session active-group re-set, single-session enforcement).
- **Do not reimplement the sensor driver.** `libbauthserver.so` is a
  binary blob that talks to a TrustZone TA; a clean-room replacement
  would need the TA protocol, the sensor register map, and the
  calibration data — none of which is published. The blob is the
  sensor driver, full stop.
- **The one thing a clean-room build would need, if the blob ever broke:**
  a minimal AIDL service that `dlopen`s the same 12 `ss_fingerprint_*`
  symbols and implements the same `Session` semantics (active-group
  re-set in the constructor, single session, template fallback via
  `User_<uid>_<fid>tmpl.dat`). That is a ~500-line service — the
  LineageOS one already is that service.

---

## 7. What this proves, and the next RE target

**Proven:** the fingerprint HAL is an AIDL v4 service wrapping a
multi-vendor blob; the framework contract is satisfied; the enrolment
fix is structural; the only blocking work is two props, one of which
needs a value read off the device. Fingerprint is **not** a long pole
for the HyperOS 2 port — it is a first-boot verification item.

**Next RE target: the RIL surface** (per `docs/port-plan.md` Phase 3
order — RIL/IMS/VoLTE is the #1 daily-driver blocker, and the
`libsec-ril.so` blob is the largest single unknown in the vendor set).

---

## 8. Sources + credits

- `LineageOS/android_hardware_samsung`, branch `lineage-22.2`,
  `aidl/fingerprint/` — the fingerprint service (Apache-2.0). Read via
  raw.githubusercontent.com, 2026-11-25.
- `a71-devs/android_device_samsung_m51` (lineage-22.2) + `a71-devs/
  android_device_samsung_a71-common` (lineage-22.2) — device tree,
  manifest, init rc files, sepolicy, `vendor.prop`, overlay.
  `proprietary-files.txt` greps verified 2026-11-25.
- `a71-devs/android_vendor_samsung_m51` (lineage-22.2) —
  `proprietary/vendor/lib64/libbauthserver.so` (461,768 B, AArch64,
  stripped): symbol table + strings verified 2026-11-25.
- MysticGSI `spring` — HyperOS 2 / Android 15, `system.img`
  (6,232,481,792 B, MD5 `3e6337d1dd850ae2d0f7d067f8dd191c`):
  `services.jar` (32,421,449 B) + `miui-services.jar` (9,955,131 B),
  disassembled with **baksmali 2.5.2** (JesusFreke / dexlib2, BSD).
  Framework compatibility matrix `202404` read from the same image.
- `jaso1000/Fold3-LineageOS` — the Fold3 fingerprint README, confirming
  the active-group fix pattern and the "rarely drops at boot if the HAL
  crashes" checklist. Read 2026-11-25 ~03:13 IST.
- `Arnav3078/ColorOS17-SM7150` — fingerprint @2.1 mapping + `m51.cil`
  template (prior art checked per the task; the @2.1 mapping is the
  stale manifest declaration in §1.5).
- `SpiderGirl-OS` (AstroROM fork) — HIDL→AIDL HAL swaps (prior art
  checked; the lights/vibrator/camera swap pattern, not fingerprint —
  fingerprint needed no swap).
- `docs/re-lights.md` — structure template for this document.
- `docs/blob-audit.md` — bucket A/C classification of the service vs
  the blob; `docs/port-plan.md` Phase 3 — the order this RE feeds.

---

## 9. Open items (only a booted device settles these)

1. **Sensor vendor string** — read `/sys/class/fingerprint/fingerprint/vendor`
   and `.../name` on a booted device; fill `persist.vendor.sys.fp.vendor`
   (§5.1). QBT2000 is the leading candidate; Egis ET510 second.
2. **Does the HAL open?** — first-boot logcat: `libbauthserver.so`
   dlopen + `ss_fingerprint_open` success, service registers
   `IFingerprint/default`. A failure here is a TA/kernel-driver problem,
   not a framework problem.
3. **Does `waitForDeclaredService` stall?** — if the HAL service is slow
   to start, fingerprint setup stalls (not boot). Check the first-boot
   logcat timestamps.
4. **Does enrolment survive a reboot?** — enrol one finger, reboot, check
   it still authenticates. If it drops, add the Fold3 boot-service
   re-send (§5.6).
5. **Power-key behaviour with `ro.hardware.fp.sideCap=true`** — lock/
   unlock/long-press must be unchanged (§3.7).
6. **No FOD UI** — Settings and the lockscreen must show a side-sensor
   affordance only, never an under-display fingerprint prompt (§3.6).
7. **`check_vintf`** — decides whether the HIDL 2.1 declaration stays
   or goes (§1.5).
8. **Stock vendor manifest** — extract `super.img.lz4` from the DXJ1
   firmware AP, `lpunpack` the vendor image, read
   `/vendor/etc/vintf/manifest.xml`: settles whether stock declares
   `vendor.samsung.hardware.biometrics.fingerprint` 3.0 (the Hyper371
   claim) with ground truth.
9. **HyperOS 3 matrix** — when the H3 track starts, read the H3 GSI's
   compatibility matrix: if it requires AIDL biometrics v5, the
   Samsung service needs a bump or a wrapper (§3.8).
