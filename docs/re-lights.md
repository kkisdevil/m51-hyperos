# RE: lights HAL — Galaxy M51 × HyperOS (first decompile / clean-room proof)

Date: 2026-11-24. Author: YuZora (subagent). Status: **COMPLETE — both sides
read and verified.** Samsung side: open source, no decompile needed.
Xiaomi side: `MiuiLightsService` + AOSP `LightsService` disassembled from
the spring GSI with baksmali 2.5.2. **Headline correction to the earlier
draft: the MiuiLightsService NPE does NOT fire in this HyperOS 2 build.**
The NPE site is real, but Xiaomi's own code already neutralises it (§3.4–
§3.5). The remaining lights work is a silent no-op notification LED and
brightness correctness — not a boot crash.

## 0. Verdict up front

The Samsung lights HAL is **not a blob — it is open source**. It lives in
`LineageOS/android_hardware_samsung`, branch `lineage-22.2`, directory
`aidl/light/` (Apache-2.0), and the m51/a71 device tree builds it from
source. It exposes exactly **one** light: `BACKLIGHT` (id 0).

The Xiaomi side was the real decompile target, and it is now read in full:
`MiuiLightsService` (2,971 lines of smali) plus its AOSP parent
`LightsService` (455 lines) from the spring HyperOS 2 GSI. The
long-assumed boot crash — `MiuiLightsService` dereferencing the missing
Xiaomi notification light — **does not happen in this build**, for three
independent reasons (§3.5):

1. **Xiaomi pads the light map itself.** `populateAvailableLightsforMiui()`
   fills `mLightsById` with synthetic `HwLight`s for ids `size()..7`
   *before* the four virtual lights are created, so `mLightsById.get(4)`
   (NOTIFICATIONS) always returns a synthetic entry on m51, never null.
2. **Every `mLightsByType[4]` access is null-checked** (`setLightLocked`,
   `updateLightEnableAndType`, `updateLightState`).
3. **The AOSP parent catches the HAL's refusal.** A set to the synthetic
   id-4 light reaches the Samsung HAL, which answers
   `EX_UNSUPPORTED_OPERATION`; `LightsService$LightImpl` catches
   `RemoteException` *and* `UnsupportedOperationException` and logs
   "Failed issuing setLightState" instead of crashing.

**The mismatch in one paragraph:** the Samsung lights HAL exposes exactly
one light — `BACKLIGHT` (id 0) — because the m51 has no notification LED
and no capacitive buttons. `MiuiLightsService` expects a `NOTIFICATIONS`
light (id 4); on HyperOS 1 (the A03's build) the lookup returned null and
the code dereferenced it, crashing `system_server` at boot. On this
HyperOS 2 build the same lookup returns a *synthetic* light Xiaomi
creates itself, so boot proceeds — but the notification LED is then a
silent no-op: every notification-light set is answered
`EX_UNSUPPORTED_OPERATION` by the HAL and swallowed by a log line. The
fix is therefore no longer a boot-unblocking smali patch; it is (a) a
real, no-op `NOTIFICATIONS` light in the Samsung HAL so the framework
path is honest instead of accidentally working, and (b) the brightness
overlay, which is the actual user-visible lights work on this device.
The smali null-guard is kept as *optional* hardening (§6.2), not a
requirement. Details in §3–§6.

## 1. Samsung side — the lights HAL (open source, verified)

### 1.1 Where it lives

| Item | Value |
|---|---|
| Source repo | `LineageOS/android_hardware_samsung`, branch `lineage-22.2` |
| Directory | `aidl/light/` (7 files, all read 2026-11-24) |
| License | Apache-2.0 (LineageOS) |
| Interface | AIDL `android.hardware.light` **version 2**, `ILights/default` |
| Binary built | `android.hardware.light-service.samsung` (`/vendor/bin/hw/…`, `vendor: true`) |
| Pulled in by | `a71-devs/android_device_samsung_a71-common` `common.mk:166-168` (`# Lights` → `PRODUCT_PACKAGES += android.hardware.light-service.samsung`) |
| Blob-audit bucket | **A — source-built in tree** (`docs/blob-audit.md` line 67). Not a blob. |

Files (all fetched from the pinned branch, byte counts as read):

| File | Size | Role |
|---|---|---|
| `Lights.cpp` | 5,564 B | The whole implementation |
| `Lights.h` | 1,486 B | Class declaration |
| `samsung_lights.h` | 1,931 B | Default sysfs nodes + LED factors |
| `service.cpp` | 767 B | `main()`: registers the service |
| `Android.bp` | 567 B | Build rule (`samsung_header_path_defaults`, `vintf_fragments`) |
| `android.hardware.light-service.samsung.rc` | 152 B | init service `vendor.light-default`, class hal, user/group system |
| `android.hardware.light-service.samsung.xml` | 200 B | VINTF fragment: AIDL `android.hardware.light` v2, `ILights/default` |

**Correction to earlier docs:** `reverse-engineering.md` §3 row 8 and the
skill §8.4 call the Samsung lights HAL "HIDL lights". It is not HIDL — it
is the **AIDL** lights service (v2), built from `aidl/light/` and linked
against `android.hardware.light-V2-ndk`. The Phase 0 note that "light is
built but not declared in the manifest" is also only half true: it is not
in `a71-common/manifest.xml`, but the `.xml` above is a VINTF fragment
(`vintf_fragments` in the `.bp`), so the HAL **is** discoverable through
VINTF. Both corrections are recorded in the skill (v2.7).

### 1.2 The device-tree override — why only BACKLIGHT exists

The default header `samsung_lights.h` defines five nodes
(`PANEL_BRIGHTNESS_NODE` `/sys/class/backlight/panel/brightness`,
`PANEL_MAX_BRIGHTNESS_NODE`, `BUTTON_BRIGHTNESS_NODE`
`/sys/class/sec/sec_touchkey/brightness`, `LED_BLINK_NODE`
`/sys/class/sec/led/led_blink`, `LED_BLN_NODE`
`/sys/class/misc/backlightnotification/notification_led`) — but the
device tree **overrides the whole header**. `a71-devs/
android_device_samsung_a71-common`, branch `lineage-22.2`,
`include/samsung_lights.h` (2024, LineageOS, Apache-2.0) is the entire
file:

```c
#define PANEL_BRIGHTNESS_NODE "/sys/class/backlight/panel0-backlight/brightness"
#define PANEL_MAX_BRIGHTNESS_NODE "/sys/class/backlight/panel0-backlight/max_brightness"
```

Nothing else. No `BUTTON_BRIGHTNESS_NODE`, no `LED_BLINK_NODE`, no
`LED_BLN_NODE`, no LED brightness factors. The `.bp` uses
`samsung_header_path_defaults`, which puts the device tree's `include/`
first, so **this override is what gets compiled** — the defaults never
apply. The m51 tree itself (`android_device_samsung_m51`, 46 files) has
no lights/LED/include override at all; it inherits a71-common's.

Why this is correct hardware: the m51 has **no notification LED** and **no
capacitive buttons** (on-screen navigation). The kernel defconfig
(`kernel/m51_defconfig`, run #8 savedefconfig) confirms there is no Samsung
`sec` LED driver to drive — only QCOM/QPNP flash + `CONFIG_LEDS_QTI_TRI_LED`
(flash/charging, not a notification LED) and `CONFIG_BACKLIGHT_QCOM_SPMI_WLED`.
There is simply no LED for a `NOTIFICATIONS` light to drive.

### 1.3 Function map — every function in the HAL, understood and renamed

All names below are the real ones from the source (no renaming was needed —
it is open source). `Lights.cpp` is 5,564 bytes; the whole HAL is ~9 KB of
source. The constructor's `#ifdef` guards are compile-time: with the
a71-common override header, only the `BACKLIGHT` branch is compiled in.

| Function (real name) | What it does, in plain words |
|---|---|
| `set(path, value)` (template, file-static) | Opens a sysfs node, writes the value + newline, closes it. Silently does nothing if the node does not exist (ofstream fails). |
| `get(path, def)` (template, file-static) | Reads a number from a sysfs node; returns `def` if the read fails. |
| `Lights::Lights()` (constructor) | Registers the lights this device has: **always** `BACKLIGHT`; `BUTTONS` only if `BUTTON_BRIGHTNESS_NODE` is defined; `BATTERY`/`NOTIFICATIONS`/`ATTENTION` only if `LED_BLINK_NODE` is defined. **On m51: only `BACKLIGHT` is registered.** |
| `Lights::setLightState(id, state)` | Looks the id up in the registered map. Unknown id → `EX_UNSUPPORTED_OPERATION`. Known id → calls its handler under a mutex, returns OK. |
| `Lights::handleBacklight(state)` | Turns the requested colour into a brightness (`rgbToBrightness`), scales 0–255 up to the panel's real maximum (read from `max_brightness`, default 255), writes it to `panel0-backlight/brightness`. |
| `Lights::handleButtons(state)` | (Not compiled on m51.) Binary on/off: 1 if any colour channel is set, else 0. |
| `Lights::handleBattery / handleNotifications / handleAttention(state)` | (Not compiled on m51.) Remember the state, then call `setNotificationLED()`. |
| `Lights::setNotificationLED()` | (Not compiled on m51.) Priority: NOTIFICATIONS > ATTENTION > BATTERY. Writes `"0x%08x <onMs> <offMs>"` (colour, flash on/off ms) to `led_blink`; sets the BLN node 1/0 when a notification is active. |
| `Lights::calibrateColor(color, brightness)` | (Not compiled on m51.) Scales each colour channel by `LED_ADJUSTMENT_R/G/B` (all 1.0 in the default header) and by the per-light brightness factor. |
| `Lights::getLights()` | Returns every registered light as `{id, type, ordinal=0}`. **On m51: a one-element list — `{0, BACKLIGHT, 0}`.** |
| `Lights::rgbToBrightness(state)` | Luminance from colour: `(77*R + 150*G + 29*B) >> 8`. |
| `main()` (`service.cpp`) | Registers the service as `android.hardware.light.ILights/default` with the service manager, joins the binder thread pool. |

### 1.4 The backlight scale — the number that matters

The panel node is `panel0-backlight`, and its maximum is **not 255**.
OneOS's Samsung backlight work (Arnav's project, `switcher/patches/
samsung_backlight_curve.py` + `OneOSPanelBacklight.smali`, read 2026-11-24)
records from One UI's own SurfaceFlinger logs that Samsung's composer maps
the backlight float linearly onto **panel0-backlight 0..13510**. The
LineageOS HAL already handles this correctly: `handleBacklight()` reads
`max_brightness` from sysfs and scales the 0–255 value up to it
(`brightness * max_brightness / 255`), so the framework's 0–255 world and
the panel's 0–13510 world are already bridged at the HAL. The framework
side (brightness curve / auto-brightness tables) is an overlay matter, §5.3.

## 2. The AIDL lights interface (verified from AOSP)

Source: AOSP `platform/hardware/interfaces`, branch `main`,
`light/aidl/android/hardware/light/` (fetched 2026-11-24).

`ILights` has exactly two methods:

```aidl
void setLightState(in int id, in HwLightState state);
HwLight[] getLights();
```

- `setLightState`: "If control over an invalid light is requested, this
  method exists with `EX_UNSUPPORTED_OPERATION`." (AOSP doc comment,
  verbatim.) The Samsung HAL implements exactly this.
- `getLights`: "Discover what lights are supported by the HAL
  implementation." Returns `HwLight[]` — each `{int id; LightType type;
  int ordinal;}`.

`LightType` enum (verified values):

| Value | Name |
|---|---|
| 0 | BACKLIGHT |
| 1 | KEYBOARD |
| 2 | BUTTONS |
| 3 | BATTERY |
| 4 | NOTIFICATIONS |
| 5 | ATTENTION |
| 6 | BLUETOOTH |
| 7 | WIFI |
| 8 | MICROPHONE |
| 9 | CAMERA |

So on m51, `getLights()` returns `[{id: 0, type: BACKLIGHT, ordinal: 0}]`
and nothing else. Any caller asking for id 4 (`NOTIFICATIONS`) gets
`EX_UNSUPPORTED_OPERATION` from `setLightState`, and — critically — gets
**no entry at all** from `getLights()`.

## 3. Xiaomi side — MiuiLightsService, read from the spring GSI

### 3.0 What was read, and how

| Item | Value |
|---|---|
| GSI | `Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip`, 3,122,721,686 B, MD5 `3e6337d1dd850ae2d0f7d067f8dd191c`, SHA-256 `ed6c670ab9f7eb87dfbd713d348809a6546c130f83b8799cc9fac1b5acd1a03d` |
| Image | `system.img`, 6,232,481,792 B, **ext4** (magic `0x53EF` at offset 1080) — not EROFS |
| `miui-services.jar` | `/system_ext/framework/miui-services.jar`, 9,955,131 B; single `classes.dex`, 9,943,396 B |
| `services.jar` | `/system/framework/services.jar`, 32,421,449 B; `classes.dex` 11,565,760 B, `classes2.dex` 11,761,228 B, `classes3.dex` 8,988,604 B |
| `miui-framework.jar` | `/system_ext/framework/miui-framework.jar`, 6,421,078 B |
| Tooling | baksmali/smali **2.5.2** (org.smali, Maven Central), OpenJDK **25.0.5.1** (installed on the VM 2026-11-24 — `java` was not present before) |
| Working dir | `/tmp/re-lights/` (`miui-services-smali/`, `services-smali/`, `services2-smali/`, `miui-framework-smali/`, jars) |

**Tooling gotcha, record it:** `baksmali d services.jar` silently
disassembled only `classes.dex` — the lights package lives in
`classes2.dex` and was simply absent from the output (99 MB of smali,
no `com/android/server/lights/`). The class *is* defined there
(verified by parsing the dex class-def tables with Python:
`classes2.dex` defines `LightsService`, `LightsService$LightImpl`,
`VintfHalCache`, `LightsManagerBinderService`, `LogicalLight`;
`classes.dex` and `classes3.dex` define none of them). Fix: extract
`classes2.dex` from the jar and disassemble the dex file directly.
**Check: whenever a class is missing from a baksmali jar dump, parse
the dex class-def tables before concluding the class is absent.**

Prior art, already known before the GSI was read:

- The A03 project's published record (`w111user/
  hyperos-gsi-samsung-galaxy-a035f`, README, milestone **T1.5 — Initial
  HyperOS 1 Boot Compatibility**): "Samsung's A03 does not expose the
  Xiaomi notification light expected by HyperOS. The original framework
  dereferenced a missing light object during startup, causing a
  `NullPointerException`. A null-safe fallback was added to
  `miui-services.jar`." After that fix (plus the fd-allowlist fix),
  "HyperOS 1 was able to reach the graphical environment."
- OneOS's HyperOS patch set (`fahadalijaved/OneOS`, `switcher/patches/`,
  read 2026-11-24) has **no** `MiuiLightsService` patch — its guest runs on
  One UI's vendor, whose lights HAL exposes the notification light, so the
  NPE does not occur there. Its Samsung backlight work
  (`samsung_backlight_curve.py`, `OneOSPanelBacklight.smali`) is used in
  §5.3 instead. Credit both projects in `CREDITS.md` when their material
  is used.

### 3.1 Which lights service actually starts on HyperOS 2

The dispatch is three levels deep, all read from the GSI:

1. AOSP `SystemServer` (`services.jar`, `SystemServer.smali`,
   file lines 4416–4427): at "StartLightsService" it calls
   `SystemServerStub.get().createLightsServices()` and starts
   whatever class that returns via `SystemServiceManager.startService()`.
2. `SystemServerStub.createLightsServices()`
   (`SystemServerStub.smali`, file lines 90–94) returns the **AOSP**
   `LightsService.class` unconditionally — the stub is the fallback.
3. **Xiaomi overrides it.** `SystemServerImpl.createLightsServices()`
   (`miui-services.jar`, `SystemServerImpl.smali`, file lines 1871–1921)
   is the override that actually runs on HyperOS:

```java
// Java reconstruction from the smali (SystemServerImpl, lines 184–194)
Class<?> clazz = LightsService.class;              // AOSP fallback
try {
    if (ColorLightManager.isSupportLedStrip()) {
        clazz = Class.forName("com.android.server.lights.HyperLightsService");
    } else {
        clazz = Class.forName("com.android.server.lights.MiuiLightsService");
    }
} catch (ClassNotFoundException e) {
    Log.e("SystemServerI", "Failed to find MiuiLightsService", e);
}
return clazz;
```

`ColorLightManager.isSupportLedStrip()` (`miui-framework.jar`,
`ColorLightManager.smali`, file lines 175–232) reads the boolean
system resource `0x110500ca` (MIUI framework resources) and falls
back to `isSupportVersion()` if that is false. The resource value on
the spring GSI was **not resolved from the disassembly alone** (it
needs a resources.arsc parse); the source device for this GSI (Redmi
15 5G / POCO M7 Plus 5G, Snapdragon 6s Gen 3) has no LED strip, so
the value is false in practice and **`MiuiLightsService` is the
service that starts on m51**. First-boot check (§9): confirm in
logcat which class `SystemServiceManager` started.

`HyperLightsService` (`miui-services.jar`, 2,425 lines smali, also
extends `LightsService`, also reads `mLightsById` at several sites)
is the alternate branch and was **not** audited line by line — it only
runs if `isSupportLedStrip()` is ever true. If that ever happens,
audit it before trusting it.

### 3.2 The AOSP parent — `LightsService` (services.jar, classes2.dex)

`LightsService.smali`, 455 lines. The constructor chain:

- `LightsService(Context)` (file line 90) builds its HAL supplier from
  `LightsService$VintfHalCache` (file lines 36–209: lazily looks up
  `ILights/default` via the service manager; `binderDied()` /
  `get()` are `declared-synchronized`) and delegates to the
  three-argument constructor.
- `LightsService(Context, Supplier<ILights>, Looper)` (file line 111):

```java
// Java reconstruction (file lines 132–185)
mLightsByType = new LightImpl[8];              // indices 0..7 valid
mLightsById = new SparseArray<>();
mService = new LightsService$1(this);          // LightsManager local service
mH = new Handler(looper);
mVintfLights = (supplier.get() != null) ? supplier : null;
populateAvailableLights(context);
mManagerService = new LightsManagerBinderService(this);
```

`populateAvailableLights(context)` (file line ~215): if
`mVintfLights != null` → `populateAvailableLightsFromAidl`, else →
`populateAvailableLightsFromHidl`. Then a reverse loop over
`mLightsById` fills `mLightsByType[type]` for each light, with a
bounds check (`0 <= type < mLightsByType.length`).

`populateAvailableLightsFromAidl` (file line ~288): calls
`mVintfLights.get().getLights()` (file line 309) and puts one
`LightImpl` per `HwLight` into `mLightsById`. A `RemoteException`
from the HAL is **caught and logged** ("Unable to get lights from
HAL") — a missing HAL leaves the map empty, it does not crash.

`populateAvailableLightsFromHidl` (file line ~343): the fallback when
there is no AIDL HAL at all — it creates **synthetic** lights for
ids 0..7 (`id = (byte) i`, `ordinal = 1`, `type = (byte) i`) and puts
them in `mLightsById`. Note the shape: AOSP itself already does the
synthetic-light trick Xiaomi repeats in §3.3.

`onStart()` (file line ~440): publishes the `LightsManager` local
service and the `"lights"` binder service. `onBootPhase()` does
nothing in the parent.

The last safety net — `LightsService$LightImpl.setLightLocked`
(`LightsService$LightImpl.smali`): the `ILights.setLightState(...)`
call (file line 251) sits inside a try block whose catch clauses
(file lines 275–276) catch **both** `RemoteException` **and**
`UnsupportedOperationException`, and log
`"Failed issuing setLightState"` (file line 297). An
`EX_UNSUPPORTED_OPERATION` from the HAL therefore ends as a log
line, never a crash.

**On m51, after the parent constructor:** `mLightsById = {0:
LightImpl(BACKLIGHT)}`, `mLightsByType[0] = that LightImpl`,
`mLightsByType[1..7] = null`.

### 3.3 `MiuiLightsService` — constructor and the padding loop

`MiuiLightsService.smali`, 2,971 lines. The constructor (file line
604) runs the parent constructor first, then:

```java
// Java reconstruction from the smali (constructor, file lines 604–737)
populateAvailableLightsforMiui();   // file line 677 — BEFORE the four lights below
mColorfulLight = new LightImpl(this, context, 8);   // file line ~700
mMusicLight   = new LightImpl(this, context, 9);   // file line ~711
mPrivacyLight = new LightImpl(this, context, 10);  // file line ~722
mLedLight     = new LightImpl(this, context, 11);  // file line ~733
```

The four ids 8–11 are Xiaomi's **virtual** lights (the parameter is
literally named `mFakeId` in the constructor signature). All four
share one underlying hardware light — id 4, NOTIFICATIONS (§3.4).

`populateAvailableLightsforMiui()` (file line 1386, Java lines 124+)
has **two** loops:

```java
// Loop 1 (Java 124–127): wrap each HAL light into a Miui LightImpl
// and store it in mLightsByType[key].
for (int i = mLightsById.size() - 1; i >= 0; i--) {
    int type = mLightsById.keyAt(i);
    if (0 <= type && mLightsByType != null && type < mLightsByType.length) {
        mLightsByType[type] = new LightImpl(this, mContext,
            ((LightsService.LightImpl) mLightsById.valueAt(i)).mHwLight, null);
    }
}
// Loop 2 (Java 131+): pad mLightsById with SYNTHETIC HwLights.
for (int i = mLightsById.size(); i < 8; i++) {
    HwLight hw = new HwLight();
    hw.id = (byte) i; hw.ordinal = 1; hw.type = (byte) i;
    mLightsById.put(i, new LightsService.LightImpl(this, mContext, hw));
}
```

The padding loop's bound is visible in the smali (file lines
1465–1468): `:goto_3a` / `const/16 v2, 0x8` / `if-ge v0, v2, :cond_5c`.
Note what loop 2 does **not** do: it pads `mLightsById` only — it
never writes to `mLightsByType`. So after it, `mLightsByType[1..7]`
are still null, while `mLightsById` is complete for ids 0..7.

**On m51, after `populateAvailableLightsforMiui()`:** `mLightsById =
{0: real BACKLIGHT, 1..7: synthetic}`, `mLightsByType[0] = Miui
LightImpl(BACKLIGHT)`, `mLightsByType[1..7] = null`.

`loadSupportLights()` (file line ~1310) reads six `FeatureParser`
booleans — `support_led_light`, `support_button_light`,
`support_tap_fingerprint_sensor_to_home`, `support_led_colorful`,
`support_led_colorful_game`, `support_led_schedule` — defaulting to
false. On a GSI with no Samsung feature XML these are false, so the
LED branches in `updateLightEnableAndType()` do not even run on m51
(and are null-checked anyway, §3.5).

`onStart()` (file line ~2960) only calls `super.onStart()` and stores
`sInstance`. `onBootPhase(1000)` (file line ~2898,
`PHASE_ACTIVITY_MANAGER_READY`) calls `loadSupportLights()`,
`updateLightEnableAndType()`, creates the `LightContentObserver`,
fetches `BatteryManagerInternal`, and registers the
`UserSwitchReceiver` — no direct light dereference.
`isTurnOnNotificationLight()` (file line ~1290) only reads the
`Settings.Secure` int `notification_light_turn_on`.

### 3.4 The NPE site — exact, and why it does NOT fire here

`MiuiLightsService$LightImpl.<init>(service, context, int mFakeId)`
(`MiuiLightsService$LightImpl.smali`, file line 128; Java lines
240–245):

```smali
.line 241
iget-object v0, p1, Lcom/android/server/lights/MiuiLightsService;->mLightsById:Landroid/util/SparseArray;

const/4 v1, 0x4                                        ; file line 152

invoke-virtual {v0, v1}, Landroid/util/SparseArray;->get(I)Ljava/lang/Object;   ; file line 154

move-result-object v0

check-cast v0, Lcom/android/server/lights/LightsService$LightImpl;

iget-object v0, v0, Lcom/android/server/lights/LightsService$LightImpl;->mHwLight:Landroid/hardware/light/HwLight;   ; file line 160 — THE DEREFERENCE

invoke-direct {p0, p1, p2, v0}, Lcom/android/server/lights/LightsService$LightImpl;-><init>(Lcom/android/server/lights/LightsService;Landroid/content/Context;Landroid/hardware/light/HwLight;)V
```

In Java:

```java
// MiuiLightsService$LightImpl.java, lines 240–245 (reconstructed)
private LightImpl(MiuiLightsService service, Context context, int mFakeId) {
    this$0 = service;
    // line 241 — THE NPE SITE:
    super(service, context,
          ((LightsService.LightImpl) service.mLightsById.get(4)).mHwLight);
    mLastLightStyle = -1;
    mIsShutDown = false;
    mId = mFakeId;
    mDisabled = (mId == 2 || mId == 3);
}
```

The lookup hardcodes `const/4 v1, 0x4` — **light id 4 =
NOTIFICATIONS** — and dereferences `->mHwLight` unconditionally. If
`mLightsById.get(4)` returned null, the `iget-object` at file line
160 throws `NullPointerException` inside `MiuiLightsService.<init>`,
which runs during `system_server` startup — the A03 crash, exactly
as the A03 record describes it.

**Why it does not fire in this build:** the constructor calls
`populateAvailableLightsforMiui()` (file line 677) *before* creating
the four virtual lights (file lines ~700–733). On m51 the parent left
`mLightsById` with size 1 (only id 0), so loop 2 pads ids 1–7 —
**including id 4** — with synthetic `HwLight`s. When the first
virtual light (`mColorfulLight`, id 8) is constructed, `get(4)`
returns the synthetic `LightImpl`, whose `mHwLight` is the synthetic
`HwLight{id=4, ordinal=1, type=4}` — non-null. The dereference
succeeds. All four virtual lights are backed by that same synthetic
id-4 light. Xiaomi added this padding in HyperOS 2 (the A03's
HyperOS 1 build evidently did not have it, or not in this form);
the A03 porters' null-safe fallback is the same idea, applied from
the outside.

### 3.5 The three guards, audited

| Guard | Where (file:line) | What it does on m51 |
|---|---|---|
| 1. Padding loop | `MiuiLightsService.smali:1386`, loop 2 at `1465–1468` | `mLightsById.get(4)` is never null: synthetic `HwLight{id=4, ordinal=1, type=4}` is inserted before any virtual light is created. |
| 2. Null checks on `mLightsByType[4]` | `MiuiLightsService$LightImpl.smali:1010` (`setLightLocked`, Java lines 326–327: `aget-object … [4]` then `if-eqz v0, :cond_b9`); `MiuiLightsService.smali:1942` (`updateLightEnableAndType`, Java lines 182–187, null checks on ids 2, 4, 3); `MiuiLightsService.smali:2166` (`updateLightState`, Java lines 999–1003, null checks on ids 3 and 4) | `mLightsByType[4]` is null on m51 (loop 2 never fills it) and every access checks first. `mLightsByType` itself is `new LightImpl[8]` (parent, file lines 132–136), so index 4 is in bounds — no `ArrayIndexOutOfBoundsException` either. |
| 3. AOSP catch of the HAL's refusal | `LightsService$LightImpl.smali:251` (the `setLightState` call), catch clauses at `275–276` (`RemoteException` + `UnsupportedOperationException`), log at `297` | A set to the synthetic id-4 light reaches the Samsung HAL, which returns `EX_UNSUPPORTED_OPERATION`; it is caught and logged ("Failed issuing setLightState"), not thrown. |

Also checked and safe: `updateLightState()` (file line 2166)
dereferences `mColorfulLight` without a null check — but that field
is `final` and assigned in the constructor (file line ~700), so it is
non-null whenever the service exists. `doCancelColorfulLightLocked()`
(file line 943) is the same. `updateLightEnableAndType()` only
touches LED paths when the `FeatureParser` flags are true (false on
m51 by default).

### 3.6 What actually happens on m51 at runtime (predicted from the code)

- **Boot succeeds.** `MiuiLightsService` constructs, `system_server`
  does not crash on lights. The A03 boot crash is already fixed in
  this HyperOS 2 build.
- **The notification LED is a silent no-op.** Any notification-light
  set travels: `mLedLight.setLight(...)` → `realSetLightLocked` →
  parent `setLightLocked` → `ILights.setLightState(4, …)` → Samsung
  HAL returns `EX_UNSUPPORTED_OPERATION` → caught → log line
  `"Failed issuing setLightState"`. Nothing lights up — correctly,
  because there is no LED — but the path is accidental, not
  designed, and it spams that log line on every notification.
- **Backlight works.** `mLightsByType[0]` is the real BACKLIGHT
  light; `setLightLocked` for id 0 goes to `realSetLightLocked` and
  the HAL writes `panel0-backlight/brightness` with the 0–13510
  scaling (§1.4). Brightness correctness is an overlay matter (§5.3),
  not a HAL matter.
- **Flashlight** is unaffected by lights (camera HAL, A03 precedent)
  — expect a lights-HAL shim only if the QS tile fails.

### 3.7 Residual risks — what was NOT proven

- **The one case that could still NPE:** the padding loop starts at
  `mLightsById.size()` and assumes ids `0..size()-1` are present. If
  a HAL returned ≥5 lights with id 4 missing (e.g. ids
  `{0,1,2,3,5,6,7,8}` — size 8, loop never runs), `get(4)` would be
  null and the constructor would NPE. The Samsung HAL returns exactly
  `{0}`, so this cannot happen on m51. It is a latent fragility in
  Xiaomi's code, not a live m51 bug — the optional patch in §6.2
  closes it anyway.
- **`HyperLightsService` is unaudited.** It only starts if
  `ColorLightManager.isSupportLedStrip()` is true; the resource value
  `0x110500ca` was not resolved from the disassembly. First-boot
  check (§9) settles which service started.
- **No on-device proof yet.** Everything in §3.6 is a code-level
  prediction. It needs the first boot's logcat (which service
  started, any `Failed issuing setLightState` lines, any lights NPE)
  to become fact.

## 4. The mismatch (interface map — corrected)

| Side | What it provides / expects | Outcome on this build |
|---|---|---|
| Samsung HAL (`ILights/default`, AIDL v2) | Exactly one light: `BACKLIGHT` (id 0). `getLights()` → 1 element. `setLightState(4, …)` → `EX_UNSUPPORTED_OPERATION`. | Correct for the hardware (no LED). |
| MiuiLightsService (HyperOS 2, spring GSI) | Expects a `NOTIFICATIONS` light (id 4); creates four virtual lights (8–11) backed by it. | **No crash:** the padding loop supplies a synthetic id-4 light before the lookup runs; every other access is null-checked; the HAL's refusal is caught. |
| m51 hardware | No notification LED, no capacitive buttons. | The notification light is a silent no-op — by accident, not by design. |
| AOSP parent (`LightsService`) | `mLightsByType[8]`; HIDL fallback creates synthetic lights 0..7; catches `RemoteException` from `getLights()` and from `setLightState()`. | Provides the safety nets Xiaomi's code relies on. |

Secondary mismatch (brightness, not a crash): the framework's brightness
world is 0–255 / nits, the panel's is 0–13510. The HAL already scales it
(§1.4); the remaining piece is the overlay's brightness tables (§5.3).

The earlier draft of this doc said the mismatch was "lookup finds
nothing → NPE → system_server crash loop". That was the HyperOS 1 / A03
situation. **On this HyperOS 2 build it is wrong** — see §3.4–§3.6. The
correction is the main finding of this pass.

## 5. The fix (three parts, in order — reframed by §3)

### 5.1 Optional hardening: smali null-safe fallback in `miui-services.jar` (A03 pattern, now optional)

The boot does **not** need this patch on this build. It is kept as
defence-in-depth for the latent case in §3.7 (a HAL returning ≥5 lights
with id 4 missing) and for any future HyperOS build that changes the
padding loop. If it is applied, it goes at the exact site in §3.4
(`MiuiLightsService$LightImpl.<init>`, file line 128) and the fallback
must be a **synthetic `HwLight{id=4, ordinal=1, type=4}`** — exactly what
Xiaomi's padding loop creates — so a set still targets id 4 and is
refused cleanly by the HAL. **Never fall back to id 0 (BACKLIGHT):**
that would make notification-light sets drive the screen brightness.
Exact patch text in §6.2. The patch must be scoped to the lookup site
only — no global signature or null-check disabling — and the OneOS
fail-closed rule applies: the target method must be found exactly once
or nothing is written.

### 5.2 Recommended: a no-op `NOTIFICATIONS` light in the Samsung HAL

Give the framework a `NOTIFICATIONS` light to find, so the lookup never
returns null in the first place and the path is honest instead of
accidentally working. The m51 has no LED, so the handler does nothing —
which is the correct behaviour for a phone with no LED (features that
would light it simply do nothing, silently, instead of crashing or
spamming "Failed issuing setLightState" on every notification).

Two ways to do it; the first is recommended:

- **(a) Fork `LineageOS/android_hardware_samsung` and add a proper no-op
  handler** (new fork, same as the five a71-devs forks; GPL-2.0/Apache-2.0
  per the files, credit LineageOS). Add `NOTIFICATIONS` to the registered
  map with a handler that discards the state. Clean, explicit, versioned.
  Clean-room C for the handler is in §6.1.
- **(b) Quick alternative, no fork:** in the a71-common override
  `include/samsung_lights.h`, add `#define LED_BLINK_NODE "/dev/null"`.
  That compiles the LED handlers in (BATTERY/NOTIFICATIONS/ATTENTION all
  get registered) and every LED write goes to `/dev/null` — a silent
  no-op through the existing override mechanism. It works, but it is a
  hack (it also registers BATTERY/ATTENTION, and it hides the intent
  behind a path), so it is the fallback, not the plan.

Either (a) or (b) makes `getLights()` return the notification light;
(5.1) stays in place as defence-in-depth, because a framework service
should never crash on a missing light.

### 5.3 RRO overlay — brightness tables (no crash, needed for correct brightness)

Ship the m51 overlay with the stock brightness tables, taken verbatim from
`a71-devs/android_device_samsung_a71-common`
`overlay/frameworks/base/core/res/res/values/config.xml` (lineage-22.2,
read 2026-11-24):

- `config_autoBrightnessLevels` (lux): 1, 2, 3, 4, 5, 10, 15, 20, 25, 30,
  35, 40, 45, 50, 100, 300, 500, 1000, 2000, 2999, 3000, 4000, 5000, 6000,
  7000, 8000, 9000, 10000, 20000, 40000.
- `config_autoBrightnessDisplayValuesNits` (same order, one extra value):
  12, 17, 25, 30, 35, 40, 62, 85, 108, 119, 119, 119, 123, 123, 126, 134,
  152, 178, 249, 420, 420, 468, 515, 563, 610, 658, 705, 753, 776, 800,
  800. Maximum 800 nits.
- `config_screenBrightnessBacklight` / `config_screenBrightnessNits`:
  the nits↔backlight curve (backlight 0, 1, 2, 3, …; nits 2, 2.1, 3.2,
  3.3, 4.4, …). Copy the full arrays from the same file — do not
  re-type from memory.
- `config_dozeAlwaysOnDisplayAvailable` = true,
  `config_dozeAlwaysOnEnabled` = false (stock a71-common values; AOD
  stays off by default until the AOD work lands).

Plus the TrebleDroid Samsung backlight fixes named in
`reverse-engineering.md` §3 row 8: "extended brightness range" +
"alternative backlight scale". And OneOS's nits-curve precedent
(`OneOSPanelBacklight.smali`: Samsung composer maps the backlight float
linearly onto panel0-backlight 0..13510; its nits→float table came from One
UI's own SurfaceFlinger logs) is the model if the GSI's brightness curve
still misbehaves after the overlay — measure on device first, do not copy
its table (it is the Z Fold8 Ultra's panel, scaled, not the m51's).

Flashlight: the QS flashlight works via the camera HAL only when the camera
app holds it (A03). Expect a lights-HAL shim for it if the QS tile fails;
not part of this fix.

## 6. Clean-room reconstruction (labelled — never presented as original source)

Everything in this section is **reconstructed from observed behaviour**
(the open HAL source in §1, the AIDL interface in §2, the disassembled
Xiaomi/AOSP code in §3, the A03 record). It is new code written to do the
same job, not recovered source. The Java reconstructions in §3 are
re-wordings of the smali; the smali in §6.2 is a patch written against
the disassembly, not original Xiaomi code.

### 6.1 No-op NOTIFICATIONS handler (for the forked HAL, fix 5.2a)

Drop-in addition to `Lights.cpp`, inside the `#ifdef LED_BLINK_NODE`
block's registration (or as its own handler — the point is the state is
accepted and discarded):

```cpp
// Clean-room reconstruction (YuZora, 2026-11-24) — NOT original source.
// The m51 has no notification LED, so there is no sysfs node to write.
// This handler exists only so getLights() reports a NOTIFICATIONS light
// and MiuiLightsService's lookup never returns null. It accepts the state
// and discards it.
void Lights::handleNotificationsNoOp(const HwLightState& /*state*/) {
    // Intentionally empty: no LED hardware on this device.
}
```

Registration (in `Lights::Lights()`, next to the `BACKLIGHT` line):

```cpp
mLights.emplace(LightType::NOTIFICATIONS,
                std::bind(&Lights::handleNotificationsNoOp, this,
                          std::placeholders::_1));
```

Declaration in `Lights.h` (next to `handleBacklight`):

```cpp
void handleNotificationsNoOp(const HwLightState& state);
```

### 6.2 Smali null-guard for MiuiLightsService (OPTIONAL hardening — §5.1)

Target, found exactly once: `MiuiLightsService$LightImpl.<init>
(Lcom/android/server/lights/MiuiLightsService;Landroid/content/Context;I)V`
in `miui-services.jar` (`MiuiLightsService$LightImpl.smali`, file line
128). The patch inserts a null check after the `check-cast` at file
line ~156 and before the `iget-object … ->mHwLight` at file line 160.
The fallback constructs the same synthetic `HwLight` Xiaomi's padding
loop creates (`id=4, ordinal=1, type=4`), so a set still targets id 4
and is refused cleanly by the HAL. The constructor has `.registers 7`,
so `v0`/`v1` are free to reuse.

```smali
# OPTIONAL hardening patch — apply with smali 2.5.2, reassemble
# miui-services.jar, resign. NOT required for boot on this build (§3.4).
# Original code (file lines 152–161):
#     const/4 v1, 0x4
#     invoke-virtual {v0, v1}, Landroid/util/SparseArray;->get(I)Ljava/lang/Object;
#     move-result-object v0
#     check-cast v0, Lcom/android/server/lights/LightsService$LightImpl;
#     iget-object v0, v0, Lcom/android/server/lights/LightsService$LightImpl;->mHwLight:Landroid/hardware/light/HwLight;
#     invoke-direct {p0, p1, p2, v0}, Lcom/android/server/lights/LightsService$LightImpl;-><init>(Lcom/android/server/lights/LightsService;Landroid/content/Context;Landroid/hardware/light/HwLight;)V

    const/4 v1, 0x4

    invoke-virtual {v0, v1}, Landroid/util/SparseArray;->get(I)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Lcom/android/server/lights/LightsService$LightImpl;

    if-eqz v0, :fallback_notification_light

    iget-object v0, v0, Lcom/android/server/lights/LightsService$LightImpl;->mHwLight:Landroid/hardware/light/HwLight;

    goto :have_hw_light

    :fallback_notification_light
    new-instance v0, Landroid/hardware/light/HwLight;

    invoke-direct {v0}, Landroid/hardware/light/HwLight;-><init>()V

    const/4 v1, 0x4

    iput v1, v0, Landroid/hardware/light/HwLight;->id:I

    const/4 v1, 0x1

    iput v1, v0, Landroid/hardware/light/HwLight;->ordinal:I

    const/4 v1, 0x4

    iput-byte v1, v0, Landroid/hardware/light/HwLight;->type:B

    :have_hw_light
    invoke-direct {p0, p1, p2, v0}, Lcom/android/server/lights/LightsService$LightImpl;-><init>(Lcom/android/server/lights/LightsService;Landroid/content/Context;Landroid/hardware/light/HwLight;)V
```

The field types match the AOSP HIDL-fallback code that builds the
same object (`LightsService.smali`, `populateAvailableLightsFromHidl`):
`id` is `int` (`iput`), `ordinal` is `int` (`iput`), `type` is `byte`
(`iput-byte`). The no-arg `HwLight.<init>()V` exists (used by that
same AOSP fallback).

**Do NOT "simplify" this patch by falling back to id 0 (BACKLIGHT).**
That would make every notification-light set drive the screen
brightness — a notification would flash the display. The synthetic
id-4 light is the only safe fallback on a device with no LED.

## 7. What this proves, and the next RE target

What this pass proved:

1. **The user's point holds for small, bounded pieces** — but the
   lights HAL itself did not need decompiling, because it is open source.
   The real decompile target was the Xiaomi framework jar, and the tool
   for that is baksmali (dex → smali), not Ghidra. Ghidra was not needed
   for *this* pass: the VM has `objdump`/`readelf`/`nm`/`strings`, and
   the smali toolchain is the Maven org.smali 2.5.2 jars + OpenJDK 25.
   (Separately, the main chat has since built a Ghidra 12.2 tool for
   native vendor blobs — the Mercury-rename tool, skill v2.6 — which is
   the right tool for the next targets that *are* native blobs.)
2. **"Rename the functions and make it properly sourced" is exactly the
   right method** — §1.3 is that method applied to the Samsung side
   (every function named, every sysfs node mapped, every `#ifdef`
   resolved against the real override header), and §3 is the same method
   applied to the dex side (every method read, every lookup traced to
   its exact smali line, the Java reconstructed from the bytecode).
3. **The biggest correction this pass found:** the assumed boot crash
   does not happen on HyperOS 2. The A03 record (HyperOS 1) was taken
   as the current state; reading the actual spring GSI showed Xiaomi
   already added the padding loop that neutralises the NPE, and AOSP
   already catches the HAL's refusal. **Assumption checked against
   the binary beats a cited precedent.** The same discipline applies
   to every later RE target: read the actual binary in hand, do not
   import another device's crash as fact.
4. **The second correction:** the Samsung lights HAL is AIDL v2, not
   HIDL, and it is declared via a VINTF fragment — both earlier docs
   had it wrong (§1.1, skill v2.7).
5. **Tooling lesson:** `baksmali d <jar>` silently skips
   `classes2.dex`/`classes3.dex` content in the output tree (it
   disassembled only `classes.dex` here). Always verify a "missing"
   class against the dex class-def tables before concluding it is
   absent (§3.0).

**Next RE target (recommended): the fingerprint HAL.** Same shape as
lights — small, bounded, one HAL — but it is a *blob* this time
(`android.hardware.biometrics.fingerprint-service.samsung` is source-built
per the audit, while the sensor itself is a HIDL 2.1 blob path; the
TrebleDroid HIDL fingerprint adapter + the enrolment-loss fix are the
things to RE). After that: the RIL (`libsec-ril.so` — the biggest target,
do it last, and only the `makeRil()`/SIM-power-state surface, not the
whole modem stack).

## 8. Sources + credits

- `LineageOS/android_hardware_samsung`, branch `lineage-22.2`,
  `aidl/light/` — Apache-2.0. The lights HAL source.
- `a71-devs/android_device_samsung_a71-common`, branch `lineage-22.2`,
  `include/samsung_lights.h`, `common.mk`, `overlay/.../config.xml` —
  GPL-2.0 (device tree). The override header + brightness tables.
- `a71-devs/android_device_samsung_m51`, branch `lineage-22.2` — no
  lights override (verified by tree listing).
- AOSP `platform/hardware/interfaces`, branch `main`,
  `light/aidl/android/hardware/light/` — Apache-2.0. `ILights` +
  `LightType` (BACKLIGHT=0 … CAMERA=9).
- MysticGSI spring HyperOS 2 GSI
  (`Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip`,
  MD5 `3e6337d1dd850ae2d0f7d067f8dd191c`) — the binaries read in §3:
  `miui-services.jar` (MiuiLightsService, SystemServerImpl,
  HyperLightsService), `services.jar` classes2.dex (AOSP
  LightsService), `miui-framework.jar` (ColorLightManager).
- `w111user/hyperos-gsi-samsung-galaxy-a035f` README, milestone T1.5 —
  the A03 MiuiLightsService null-safe fallback (the fix pattern, and
  the HyperOS 1 precedent this pass corrected for HyperOS 2).
- `fahadalijaved/OneOS`, `switcher/patches/` — `miui_guards.py` (the
  fail-closed smali-patch method), `samsung_backlight_curve.py` +
  `OneOSPanelBacklight.smali` (Samsung panel 0..13510 + nits→float table
  from One UI logs). Same Arnav behind the UN1CA-SM7150 fork.
- `docs/blob-audit.md` (bucket A, line 67) — lights HAL is source-built.
- `docs/reverse-engineering.md` §2.3, §3 rows 7–8, §4 gap #5;
  `docs/port-plan.md` Phase 1–2 (lights/brightness/flashlight).
- baksmali/smali 2.5.2 (org.smali, Maven Central) — the dex toolchain.

## 9. Open items

- [x] §3/§6.2: extract `miui-services.jar` from the spring GSI;
  disassemble `MiuiLightsService`; record the exact lookup + NPE site;
  write the smali patch — **DONE 2026-11-24 ~19:10 IST, with the
  correction that the NPE does not fire in this build and the patch is
  optional hardening.**
- [x] JRE install — OpenJDK 25.0.5.1 installed; baksmali 2.5.2 verified
  working on all four jars.
- [ ] Decide 5.2a (fork hardware/samsung) vs 5.2b (`/dev/null` override)
  with the user — (a) is recommended. The no-op light is now the
  primary fix, not a nice-to-have.
- [ ] `panel0-backlight` sysfs existence on the m51 kernel: the
  a71-common override header is authoritative for LineageOS on this
  device family; confirm on the first boot (`ls
  /sys/class/backlight/`).
- [x] Correct `reverse-engineering.md` §3 row 8 + skill §8.4: lights HAL
  is AIDL v2 (not HIDL) and is VINTF-declared via fragment — **skill
  corrected in v2.7; `reverse-engineering.md` still to be edited.**
- [ ] First boot (needs the real m51): confirm in logcat which lights
  service started (`MiuiLightsService` vs `HyperLightsService`), look
  for `Failed issuing setLightState` lines (expected: one per
  notification-light set until fix 5.2 lands), and confirm no lights
  NPE in `system_server`.
- [ ] Resolve the `0x110500ca` resource value in the spring GSI's
  MIUI framework resources (resources.arsc parse) — only matters if
  `HyperLightsService` ever starts; if it does, audit it before
  trusting it.
- [ ] If the optional §6.2 patch is ever applied: reassemble with
  smali 2.5.2, verify the target method was found exactly once,
  resign the jar, and boot-test. Do not apply it "just in case"
  without a boot test — it is hardening, not a fix.
