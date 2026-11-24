# M51 logging guide — one place for every log

When a ROM misbehaves on the M51 — lag, heat, a boot failure, a dead
camera, RAM pressure — the first question is always "what did the
device actually do?" This guide is the answer: **m51-logger**
(`tools/m51-logger/`) collects kernel, boot, recovery, system, camera,
CPU/GPU, RAM and misc diagnostics into ONE timestamped bundle, with a
`SUMMARY.md` that names the headline numbers and warnings. Read the
summary first; attach the whole `.tar.gz` to a bug report.

Related: the firmware download/upload flow has its own logger (see
`docs/FIRMWARE.md`) — that one logs the download, not the device.
This guide is about the device.

## What it captures

| Area | Contents | Needs root |
|---|---|---|
| Identity | `getprop`, `uname`, kernel version, cmdline, uptime, boot reason | No |
| Kernel | `dmesg` (+ LMK / avc / CamX greps), pstore `console-ramoops`, `last_kmsg`, boot block listing | Yes |
| Recovery | TWRP `recovery.log`, `last_log` | Yes (or TWRP ADB) |
| System | `logcat` all buffers (main, system, radio, events, crash), `dumpsys` (activity, window, SurfaceFlinger, display, power, battery, thermalservice, meminfo, sensorservice, telephony, media.camera, fingerprint), `settings` (system/secure/global) | No* |
| Camera | `dumpsys media.camera`, camera/CamX logcat lines | No* |
| CPU/GPU | Thermal zones (all), CPU freq/governor per core, kgsl gpuclk/gpubusy, battery temp, backlight nodes (`panel0-backlight` / `actual_brightness` / `bl_power`, sysfs range 0..13510), SurfaceFlinger refresh rates | No |
| RAM | `/proc/meminfo`, zram (size/used/algorithm), **effective swappiness from `/proc/sys/vm/swappiness`**, PSI (cpu/memory/io), vmstat, LMK params, `dumpsys meminfo` | No (LMK params: yes) |
| Misc | Battery health/current/voltage/capacity, `df`, mounts (f2fs/erofs/ext4), SELinux state + denials, RIL state, fingerprint service state (present/absent only — no biometric data), UN1CA daemons (`carbon_power_engine`, `unica-gpu`) | No (denials: yes) |

\* Without root, `logcat` shows only the caller's UID lines; full
logcat needs root (or READ_LOGS). The limitation is recorded in
`MANIFEST.txt`, not hidden.

Full collector list + root table: `tools/m51-logger/README.md`.

## How to run it

### From a PC over ADB

```bash
# USB, one device connected:
bash tools/m51-logger/collect-logs.sh
# Wireless (connects once — see "Always-on ADB" below):
bash tools/m51-logger/collect-logs.sh --connect 192.168.1.5:5555
# Pick a device explicitly:
bash tools/m51-logger/collect-logs.sh --serial M515F123456
```

Output: `m51-logs/m51-logs-YYYYMMDD-HHMMSS/` + `.tar.gz` in the
current directory (or `--out <dir>`).

### On the phone, in Termux

```bash
bash tools/m51-logger/collect-logs-termux.sh
```

Output: `/sdcard/yuzora-logs/m51-logs-YYYYMMDD-HHMMSS/` + `.tar.gz`
(falls back to `$HOME/yuzora-logs/` if the sdcard is not writable).
No PC, no network, no ADB connection at all — everything is read
locally. This is the preferred route when the phone is in hand: it
binds nothing to the network (see the security note below).

## Always-on ADB

Collecting logs over ADB works best when the connection is already
there. But the phone's adbd is flaky by design: it restarts, drops,
and re-prompts the "Allow USB debugging?" authorisation — and every
fresh connection is a new chance for a prompt. Standing rule for
this project: **hold ONE persistent ADB connection; never reconnect
per check.** `collect-logs.sh` follows it: it selects/connects the
device once and runs every collector over that one transport.

Three ways to have ADB ready, in order of preference:

### (a) Wireless debugging toggle (no root, per-session)

Settings → Developer options → Wireless debugging. Turn it on, pair
once (`adb pair <ip>:<port>` with the code), then connect
(`adb connect <ip>:<port>`). Good enough for a one-off collection.

Limits: it **resets on reboot**, and the port **can change** between
sessions, so the connect address has to be re-read each time. The
phone also has to be unlocked and on the same network as the PC.

### (b) Rooted route — persistent TCP port, adbd kept alive on boot

On a rooted M51, adbd can be made to listen on TCP at boot and stay
up: a Magisk module (or an init script) that sets the persistent
`service.adb.tcp.port` property and restarts adbd, plus the PC's
public key stored in the phone's authorised-keys file
(`/data/misc/adb/adb_keys`) so the connection is trusted across
reboots without a fresh prompt.

This is the "always-on" setup: the PC connects once and the
transport survives collection after collection. **Do not set this up
on the user's phone without his go-ahead** — it changes the phone's
boot behaviour and its network exposure (see the security note).
Documented here as an option only.

### (c) Security note — an always-listening adbd is LAN-reachable

Our own security audit flagged this: `adbd` on `0.0.0.0:5555` is
reachable from the hotspot LAN — any device on the same hotspot can
see the port, and an authorisation prompt can appear for a key the
user never approved. Rules:

- Prefer **localhost binding** when the client is on-device: Termux
  talks to adbd at `127.0.0.1:5555`, which never leaves the phone.
  The Termux collector does not need ADB at all (it reads locally),
  which is strictly better.
- Use wireless ADB only on a **trusted network**, and turn it off
  when the collection is done (`adb disconnect`, or the toggle).
- Keep the phone's screen lock on: an ADB authorisation prompt on a
  locked phone cannot be tapped by someone else.
- Never enable ADB over an open/public hotspot.

## Reading a bundle

```
m51-logs-YYYYMMDD-HHMMSS/
  SUMMARY.md     read this first — headline numbers + warnings
  MANIFEST.txt   every collector + status (OK / EMPTY / DENIED / SKIP)
  identity/ kernel/ recovery/ system/ camera/ cpu-gpu/ ram/ misc/
```

`SUMMARY.md` flags, with the file to open for each:

- **Effective swappiness != 60** — the F3 fix is not holding at
  runtime. The value is read from `/proc/sys/vm/swappiness`, never
  the prop: the `carbon_power_engine` daemon resets it to 100 at
  every boot unless the fix pack neutralises it. Check
  `misc/unica-daemons.txt` for the daemon's state.
- **zram disksize 0** — zram is disabled (F3: stock fstab zram
  should survive).
- **Hottest thermal zone above 45 °C** — the F1 cap engagement
  point (CPU cap 1.71 GHz, GPU cap 650 MHz engage at 45 °C).
- **SELinux denials** — count + `kernel/dmesg-avc.txt`.
- **Camera error lines** — count + `camera/logcat-camera.txt`.
- **LMK kills** — count + `kernel/dmesg-lmk.txt`.
- **Refresh rate != 60 Hz** — the 60 Hz pin (P0/P1) is not holding;
  see `cpu-gpu/surfaceflinger-refresh.txt`.

`DENIED` or `SKIP` entries in `MANIFEST.txt` are expected for
root-only collectors when the device is not rooted — they are not
failures of the collection.

## Attaching a bundle to a bug report

1. Run the collector as soon as possible after the problem happens
   (logcat is a ring buffer — it overwrites itself).
2. For a crash/reboot: collect again after the reboot — `pstore`
   (`console-ramoops`) and `last_kmsg` hold the pre-crash kernel log.
3. Attach the whole `.tar.gz`. Do not paste logcat inline.
4. Say in one line: ROM version, kernel version, what you were
   doing, and the `SUMMARY.md` warnings.

## What it does NOT capture

- No personal data is uploaded anywhere by these scripts; bundles
  stay local unless the user shares them.
- No biometric data: fingerprint collection is service state +
  enrolled count only, never templates.
- No account credentials, no message contents beyond what the
  device's own logs already contain. `logcat` can contain app
  content — read `SUMMARY.md` first and scrub account names /
  tokens before sharing a bundle publicly.
- No writes to the device: the collector is read-only (no flashing,
  no remount, no recovery overwrite — TWRP rule). The only writes
  are the bundle itself (PC disk, or `/sdcard/yuzora-logs/`).
- Boot image contents: without root, the boot partition cannot be
  read from a booted Android — the bundle records the block listing
  and cmdline instead. Use the build-time checks (skill §10.1) for
  boot image verification.

## Tests

```bash
bash tools/m51-logger/tests/run_tests.sh
```

Dry-run against a mock `adb` (two fixture sets: a "bad" device with
swappiness 100 + hot temps + denials, and a "good" one). 25 checks,
all passing — no phone needed.
