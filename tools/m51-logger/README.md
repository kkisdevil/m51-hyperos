# m51-logger — one-place log collector for the Galaxy M51

Collects kernel, boot, recovery, system, camera, CPU/GPU, RAM and
misc diagnostics from a real M51 into ONE timestamped bundle
(`MANIFEST.txt` + `SUMMARY.md` + the raw files, packed as `.tar.gz`).
Built for debugging our ROMs — UN1CA 5.4.0 and the HyperOS 2 port —
when something goes wrong on the device: lag, heat, boot failure,
camera, RAM pressure.

Full guide: `docs/LOGGING-GUIDE.md` (run instructions, always-on ADB
options, privacy, how to read a bundle).

## Layout

```
tools/m51-logger/
  collect-logs.sh          PC over ADB (one persistent connection)
  collect-logs-termux.sh   on-device, inside Termux (local reads only)
  lib/collect-core.sh      shared collectors + SUMMARY.md generator
  tests/                   mock-ADB dry-run (no phone needed)
  README.md                this file
```

## Run it

```bash
# PC, USB or wireless ADB, one device connected:
bash tools/m51-logger/collect-logs.sh
# Wireless, connect once:
bash tools/m51-logger/collect-logs.sh --connect 192.168.1.5:5555
# On the phone, in Termux:
bash tools/m51-logger/collect-logs-termux.sh
```

Output: `m51-logs/m51-logs-YYYYMMDD-HHMMSS/` (+ `.tar.gz`),
or on-device `/sdcard/yuzora-logs/m51-logs-YYYYMMDD-HHMMSS/`.

## Rules the collector follows

- **Read-only.** Only shell reads; nothing is written to
  system/vendor/boot/recovery. No flashing, no remount, no recovery
  overwrite (TWRP rule).
- **One persistent ADB connection.** The device is selected/connected
  once; every collector runs over that one transport. Never
  reconnect per collector — the phone's adbd flaps and re-prompts
  authorisation on reconnect.
- **Root is detected, never forced.** Root-only collectors are
  skipped and recorded as `SKIP` in `MANIFEST.txt` when `su` is
  unavailable.

## What needs root, what does not

| Collector | Needs root | Notes |
|---|---|---|
| `getprop`, `uname`, `/proc/version`, `/proc/cmdline`, `uptime`, boot reason | No | Always available over ADB shell |
| `logcat -b all/main/system/events/crash` | No* | *Without root, logcat shows only the caller's UID lines; full logcat needs root (or READ_LOGS). Recorded in MANIFEST, not hidden |
| `logcat -b radio` | No* | Same caveat as above |
| `dumpsys` (activity, window, SurfaceFlinger, display, power, battery, thermalservice, meminfo, sensorservice, telephony, media.camera, fingerprint) | No | Plain ADB shell |
| `settings list` (system/secure/global) | No | Plain ADB shell |
| Thermal zones, CPU freq/governor, kgsl gpuclk/gpubusy, battery temp/current/voltage, backlight nodes (`panel0-backlight`), `/proc/meminfo`, zram, swappiness, PSI, `/proc/vmstat` | No | Sysfs/proc reads |
| `df`, `mount` | No | Plain ADB shell |
| `dmesg` (+ LMK/avc/CamX greps) | **Yes** | `dmesg` is root-only on user builds |
| `/sys/fs/pstore/*` (console-ramoops), `/proc/last_kmsg` | **Yes** | Crash/panic logs |
| `/dev/block/bootdevice/by-name/` listing | **Yes** | Boot image info |
| TWRP `recovery.log` / `last_log` | **Yes** | Only present in recovery, or with root; DENIED/SKIP when booted in Android is expected |
| `/sys/module/lowmemorykiller/parameters/*` | **Yes** | May not exist on this kernel; EMPTY is fine |

## Bundle layout

```
m51-logs-YYYYMMDD-HHMMSS/
  SUMMARY.md            headline numbers + warnings (read this first)
  MANIFEST.txt          every collector + status (OK/EMPTY/DENIED/SKIP)
  identity/             getprop, uname, kernel version, cmdline, uptime
  kernel/               dmesg, LMK, avc, CamX, pstore, last_kmsg
  recovery/             TWRP recovery.log / last_log (when available)
  system/               logcat all buffers, dumpsys set, settings
  camera/               dumpsys media.camera, camera logcat lines
  cpu-gpu/              thermal zones, CPU/GPU freq, backlight nodes
  ram/                  meminfo, zram, swappiness, PSI, LMK, meminfo
  misc/                 battery, storage, sensors, SELinux, RIL, daemons
```

## SUMMARY.md warnings (what it flags)

- Effective swappiness != 60 — the F3 fix is not holding at runtime
  (value read from `/proc/sys/vm/swappiness`, never the prop; the
  `carbon_power_engine` daemon resets it to 100 at boot unless
  neutralised).
- zram disksize 0 — zram disabled.
- Hottest thermal zone above 45 °C — the F1 cap engagement point.
- SELinux denials, camera error lines, LMK kills — counts + file
  pointers.
- Display refresh rate != 60 Hz — the 60 Hz pin (P0/P1) not holding.

## Privacy

Logs stay local unless the user shares the bundle. `logcat` can
contain app content — read `SUMMARY.md` first, and scrub account
names / tokens before sharing a bundle publicly. No personal data is
uploaded anywhere by these scripts.
```

## Tests

```bash
bash tools/m51-logger/tests/run_tests.sh
```

Runs the collector against a mock `adb` (two fixture sets: a "bad"
device with swappiness 100 + hot temps + denials, and a "good" one)
and asserts the bundle, MANIFEST, SUMMARY warnings and tar.gz are
all correct. No phone needed.
