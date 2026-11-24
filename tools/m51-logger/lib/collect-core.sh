#!/usr/bin/env bash
# m51-logger core — shared collector definitions for the Galaxy M51.
#
# Sourced by collect-logs.sh (PC over ADB) and collect-logs-termux.sh
# (on-device). Both entry points define the same interface before
# sourcing this file:
#
#   M51_RUN     — function name: run ONE device command string, print
#                  stdout to the caller's stdout (e.g. `adb shell "$1"`,
#                  or `sh -c "$1"` on-device).
#   M51_RUN_SU  — same, but as root (`su -c "$1"`). Empty/unset when
#                  root is unavailable; root collectors are then
#                  skipped and recorded as such.
#   M51_HAS_SU  — 1 when root is available, 0 otherwise.
#   M51_OUT     — bundle directory (already created).
#   M51_TAG     — bundle tag, e.g. m51-logs-20261125-010500.
#
# Design rules (standing):
# - READ-ONLY collection only. No writes to system/vendor/boot/recovery,
#   no flashing, no `adb remount`, no recovery overwrite (TWRP rule).
# - ONE transport for the whole run: the entry point connects/selects
#   the device once and never reconnects per collector (the phone's
#   adbd flaps and re-prompts authorisation on reconnect).
# - Every collector records its status in MANIFEST.txt:
#   OK | EMPTY | DENIED | SKIP (root required, no root).
# - SUMMARY.md is generated host-side from the collected files, so it
#   works even when half the collectors were denied.
#
# Paths verified against the m51-rom-builder skill (v3.7) and the
# project docs: thermal zones, kgsl gpuclk, zram, swappiness, the
# panel0-backlight / actual_brightness / bl_power nodes (OneOS
# black-screen fix), the 60 Hz pin props, and the UN1CA daemons
# (carbon_power_engine, unica-gpu).

# ---------------------------------------------------------------- cap()
# cap <rel-path> <root: 0|1> <device command string>
# Runs the command on the device, saves stdout to $M51_OUT/<rel-path>,
# appends one line to MANIFEST.txt.
cap() {
    local rel="$1" need_root="$2" cmd="$3"
    local dest="$M51_OUT/$rel"
    mkdir -p "$(dirname "$dest")"
    if [ "$need_root" = "1" ] && [ "${M51_HAS_SU:-0}" != "1" ]; then
        printf 'SKIP (root required, no root on this device)\n' > "$dest"
        printf '%s|SKIP|root-required\n' "$rel" >> "$M51_OUT/MANIFEST.txt"
        return 0
    fi
    if [ "$need_root" = "1" ]; then
        "$M51_RUN_SU" "$cmd" > "$dest" 2>&1 || true
    else
        "$M51_RUN" "$cmd" > "$dest" 2>&1 || true
    fi
    if grep -qiE 'permission denied|operation not permitted|not found|no such file' "$dest" \
        && [ ! -s "$dest" ]; then
        printf '%s|DENIED\n' "$rel" >> "$M51_OUT/MANIFEST.txt"
    elif [ ! -s "$dest" ]; then
        printf '%s|EMPTY\n' "$rel" >> "$M51_OUT/MANIFEST.txt"
    else
        printf '%s|OK\n' "$rel" >> "$M51_OUT/MANIFEST.txt"
    fi
    return 0
}

# ------------------------------------------------------- m51_collect_all()
m51_collect_all() {
    : > "$M51_OUT/MANIFEST.txt"
    printf '# m51-logger manifest — %s\n' "$M51_TAG" > "$M51_OUT/MANIFEST.txt"
    printf '# format: <file>|<OK|EMPTY|DENIED|SKIP>|<note>\n' >> "$M51_OUT/MANIFEST.txt"

    # ---- 1. Identity / device -------------------------------------------
    cap "identity/getprop.txt"            0 "getprop"
    cap "identity/uname.txt"              0 "uname -a"
    cap "identity/proc-version.txt"       0 "cat /proc/version"
    cap "identity/proc-cmdline.txt"       0 "cat /proc/cmdline"
    cap "identity/uptime.txt"             0 "uptime"
    cap "identity/date.txt"               0 "date"
    cap "identity/boot-reason.txt"        0 "getprop sys.boot.reason; getprop ro.boot.bootreason"

    # ---- 2. Kernel -------------------------------------------------------
    cap "kernel/dmesg.txt"                1 "dmesg -T"
    cap "kernel/dmesg-lmk.txt"            1 "sh -c 'dmesg | grep -iE \"lmk|lowmemorykiller\"'"
    cap "kernel/dmesg-avc.txt"            1 "sh -c 'dmesg | grep -i avc'"
    cap "kernel/dmesg-camx.txt"           1 "sh -c 'dmesg | grep -iE \"camx|camera\"'"
    cap "kernel/pstore-list.txt"          1 "ls -l /sys/fs/pstore/"
    cap "kernel/pstore-console-ramoops.txt" 1 "cat /sys/fs/pstore/console-ramoops"
    cap "kernel/pstore-dmesg-ramoops.txt" 1 "cat /sys/fs/pstore/dmesg-ramoops-0"
    cap "kernel/last-kmsg.txt"            1 "cat /proc/last_kmsg"
    cap "kernel/boot-block-list.txt"      1 "ls -l /dev/block/bootdevice/by-name/"

    # ---- 3. Recovery (TWRP) ----------------------------------------------
    # These files exist only in recovery, or with root. When booted in
    # Android they are normally DENIED/SKIP — that is expected, not a
    # failure. Recovery logs are collected from TWRP's ADB instead.
    cap "recovery/recovery-log.txt"       1 "cat /tmp/recovery.log"
    cap "recovery/last-log.txt"           1 "cat /cache/recovery/last_log"
    cap "recovery/cache-recovery-list.txt" 1 "ls -l /cache/recovery/"

    # ---- 4. System -------------------------------------------------------
    cap "system/logcat-all.txt"           0 "logcat -b all -v threadtime -d"
    cap "system/logcat-main.txt"          0 "logcat -b main -v threadtime -d"
    cap "system/logcat-system.txt"        0 "logcat -b system -v threadtime -d"
    cap "system/logcat-radio.txt"         0 "logcat -b radio -v threadtime -d"
    cap "system/logcat-events.txt"        0 "logcat -b events -v threadtime -d"
    cap "system/logcat-crash.txt"         0 "logcat -b crash -v threadtime -d"
    cap "system/dumpsys-activity.txt"     0 "dumpsys activity"
    cap "system/dumpsys-window.txt"       0 "dumpsys window"
    cap "system/dumpsys-surfaceflinger.txt" 0 "dumpsys SurfaceFlinger"
    cap "system/dumpsys-display.txt"      0 "dumpsys display"
    cap "system/dumpsys-power.txt"        0 "dumpsys power"
    cap "system/dumpsys-battery.txt"      0 "dumpsys battery"
    cap "system/dumpsys-thermalservice.txt" 0 "dumpsys thermalservice"
    cap "system/settings-system.txt"      0 "settings list system"
    cap "system/settings-secure.txt"      0 "settings list secure"
    cap "system/settings-global.txt"      0 "settings list global"

    # ---- 5. Camera -------------------------------------------------------
    cap "camera/dumpsys-media-camera.txt" 0 "dumpsys media.camera"
    cap "camera/logcat-camera.txt"        0 "sh -c 'logcat -b all -v threadtime -d | grep -iE \"camera|camx|qcamera\"'"

    # ---- 6. CPU / GPU / thermal ------------------------------------------
    cap "cpu-gpu/thermal-zone-types.txt"  0 "cat /sys/class/thermal/thermal_zone*/type"
    cap "cpu-gpu/thermal-zone-temps.txt"  0 "cat /sys/class/thermal/thermal_zone*/temp"
    cap "cpu-gpu/thermal-zone-policy.txt" 0 "cat /sys/class/thermal/thermal_zone*/policy"
    cap "cpu-gpu/cpu-cur-freq.txt"        0 "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"
    cap "cpu-gpu/cpu-governor.txt"        0 "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
    cap "cpu-gpu/cpu-max-freq.txt"        0 "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq"
    cap "cpu-gpu/gpu-clk.txt"             0 "cat /sys/class/kgsl/kgsl-3d0/gpuclk"
    cap "cpu-gpu/gpu-busy.txt"            0 "cat /sys/class/kgsl/kgsl-3d0/gpubusy"
    cap "cpu-gpu/gpu-governor.txt"        0 "cat /sys/class/kgsl/kgsl-3d0/devfreq/governor"
    cap "cpu-gpu/battery-temp.txt"        0 "cat /sys/class/power_supply/battery/temp"
    cap "cpu-gpu/backlight-actual.txt"    0 "cat /sys/class/backlight/panel0-backlight/actual_brightness"
    cap "cpu-gpu/backlight-brightness.txt" 0 "cat /sys/class/backlight/panel0-backlight/brightness"
    cap "cpu-gpu/backlight-bl-power.txt"  0 "cat /sys/class/backlight/panel0-backlight/bl_power"
    cap "cpu-gpu/surfaceflinger-refresh.txt" 0 "sh -c 'dumpsys SurfaceFlinger | grep -iE \"refresh|fps|vsync\"'"

    # ---- 7. RAM ----------------------------------------------------------
    cap "ram/meminfo.txt"                 0 "cat /proc/meminfo"
    cap "ram/zram-disksize.txt"           0 "cat /sys/block/zram0/disksize"
    cap "ram/zram-mem-used.txt"           0 "cat /sys/block/zram0/mem_used_total"
    cap "ram/zram-orig-data.txt"          0 "cat /sys/block/zram0/orig_data_size"
    cap "ram/zram-algorithm.txt"          0 "cat /sys/block/zram0/comp_algorithm"
    cap "ram/swappiness.txt"              0 "cat /proc/sys/vm/swappiness"
    cap "ram/pressure-cpu.txt"            0 "cat /proc/pressure/cpu"
    cap "ram/pressure-memory.txt"         0 "cat /proc/pressure/memory"
    cap "ram/pressure-io.txt"             0 "cat /proc/pressure/io"
    cap "ram/vmstat-oom.txt"              0 "sh -c 'cat /proc/vmstat | grep -iE \"oom|pswp|pgfree\"'"
    cap "ram/dumpsys-meminfo.txt"         0 "dumpsys meminfo"
    cap "ram/lmk-params.txt"              1 "cat /sys/module/lowmemorykiller/parameters/*"

    # ---- 8. Battery / storage / sensors / security / radio ---------------
    cap "misc/battery-health.txt"         0 "cat /sys/class/power_supply/battery/health"
    cap "misc/battery-current.txt"        0 "cat /sys/class/power_supply/battery/current_now"
    cap "misc/battery-voltage.txt"        0 "cat /sys/class/power_supply/battery/voltage_now"
    cap "misc/battery-capacity.txt"       0 "cat /sys/class/power_supply/battery/capacity"
    cap "misc/df.txt"                     0 "df -h"
    cap "misc/mounts.txt"                 0 "sh -c 'mount | grep -E \"f2fs|erofs|ext4\"'"
    cap "misc/dumpsys-sensorservice.txt"  0 "dumpsys sensorservice"
    cap "misc/getenforce.txt"             0 "getenforce"
    cap "misc/dumpsys-telephony.txt"      0 "dumpsys telephony.registry"
    cap "misc/fingerprint-service.txt"    0 "sh -c 'service list | grep -i finger'"
    cap "misc/dumpsys-fingerprint.txt"    0 "dumpsys fingerprint"
    cap "misc/unica-daemons.txt"          0 "sh -c 'ps -A | grep -E \"carbon_power_engine|unica-gpu\"'"
    cap "misc/unica-props.txt"            0 "sh -c 'getprop | grep -i unica'"
}

# ---------------------------------------------------- m51_write_summary()
# Host-side: reads the collected files in $M51_OUT and writes SUMMARY.md.
# Every value defaults to "n/a" when its source file is missing/empty,
# so a partial bundle still gets a useful summary.
m51_write_summary() {
    local out="$M51_OUT/SUMMARY.md"
    local f v

    # Small helper: first matching line's value after the key, or n/a.
    # Usage: val <file> <grep-pattern> <sed-expr>
    val() {
        f="$M51_OUT/$1"
        if [ -f "$f" ] && [ -s "$f" ]; then
            v="$(grep -m1 -E "$2" "$f" 2>/dev/null | sed -E "$3" 2>/dev/null)"
            if [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
        fi
        printf 'n/a'
    }

    local model rom kernel uptime swappiness zram_size zram_used
    local max_temp battery_temp refresh_rate mem_free lmk_kills avc_denials
    local cam_errors daemon_state selinux_state

    model="$(val "identity/getprop.txt" 'ro\.product\.model' 's/.*\[([^]]*)\].*/\1/')"
    rom="$(val "identity/getprop.txt" 'ro\.build\.display\.id' 's/.*\[([^]]*)\].*/\1/')"
    kernel="$(val "identity/proc-version.txt" 'Linux version' 's/^Linux version ([^ ]+).*/\1/')"
    uptime="$(val "identity/uptime.txt" '.' 's/^ *//')"
    swappiness="$(val "ram/swappiness.txt" '^[0-9]+' 's/[^0-9]//g')"
    zram_size="$(val "ram/zram-disksize.txt" '^[0-9]+' 's/[^0-9]//g')"
    zram_used="$(val "ram/zram-mem-used.txt" '^[0-9]+' 's/[^0-9]//g')"
    battery_temp="$(val "cpu-gpu/battery-temp.txt" '^[0-9]+' 's/[^0-9]//g')"
    selinux_state="$(val "misc/getenforce.txt" '.' 's/[^A-Za-z]//g')"

    # Max thermal zone temp (values are millidegrees C).
    max_temp="n/a"
    f="$M51_OUT/cpu-gpu/thermal-zone-temps.txt"
    if [ -f "$f" ] && [ -s "$f" ]; then
        max_temp="$(awk '$1 ~ /^[0-9]+$/ { if ($1 > m) m = $1 } END { if (m == "") print "n/a"; else printf "%d", m / 1000 }' "$f")"
    fi

    # Refresh rate from the SurfaceFlinger dump (first "60.00" style value).
    refresh_rate="n/a"
    f="$M51_OUT/system/dumpsys-surfaceflinger.txt"
    if [ -f "$f" ] && [ -s "$f" ]; then
        refresh_rate="$(grep -m1 -oE '[0-9]+\.[0-9]+ Hz' "$f" 2>/dev/null | head -n1)"
        [ -z "$refresh_rate" ] && refresh_rate="n/a"
    fi

    # Free RAM (kB) from meminfo.
    mem_free="n/a"
    f="$M51_OUT/ram/meminfo.txt"
    if [ -f "$f" ] && [ -s "$f" ]; then
        mem_free="$(awk '/^MemFree:/ { print $2 " kB"; exit }' "$f")"
        [ -z "$mem_free" ] && mem_free="n/a"
    fi

    # Counts (0 when the source file is missing — the file, not the
    # count, is the evidence; the manifest says whether it exists).
    lmk_kills=0; avc_denials=0; cam_errors=0
    f="$M51_OUT/kernel/dmesg-lmk.txt"
    [ -f "$f" ] && lmk_kills="$(grep -ciE 'lmk|lowmemorykiller' "$f" 2>/dev/null || true)"
    f="$M51_OUT/kernel/dmesg-avc.txt"
    [ -f "$f" ] && avc_denials="$(grep -ci 'avc:' "$f" 2>/dev/null || true)"
    f="$M51_OUT/camera/logcat-camera.txt"
    [ -f "$f" ] && cam_errors="$(grep -ciE ' E |FATAL|CamX.*(error|fail)' "$f" 2>/dev/null || true)"

    daemon_state="n/a"
    f="$M51_OUT/misc/unica-daemons.txt"
    if [ -f "$f" ] && [ -s "$f" ]; then
        if grep -q 'carbon_power_engine' "$f"; then daemon_state="carbon_power_engine RUNNING"; else daemon_state="carbon_power_engine not seen"; fi
        if grep -q 'unica-gpu' "$f"; then daemon_state="$daemon_state; unica-gpu RUNNING"; fi
    fi

    # ---- Warnings --------------------------------------------------------
    local warnings=""
    if [ "$swappiness" != "n/a" ] && [ "$swappiness" != "60" ]; then
        warnings="${warnings}- WARNING: effective swappiness is ${swappiness}, not 60 — the F3 fix is not holding at runtime (check carbon_power_engine; never trust the prop, this value is from /proc/sys/vm/swappiness).\n"
    fi
    if [ "$zram_size" = "0" ]; then
        warnings="${warnings}- WARNING: zram disksize is 0 — zram is disabled (F3: stock fstab zram should survive).\n"
    fi
    if [ "$max_temp" != "n/a" ] && [ "$max_temp" -gt 45 ] 2>/dev/null; then
        warnings="${warnings}- WARNING: hottest thermal zone is ${max_temp} C (above 45 C — the F1 cap engagement point).\n"
    fi
    if [ "$avc_denials" != "0" ] && [ -n "$avc_denials" ]; then
        warnings="${warnings}- WARNING: ${avc_denials} SELinux denials (avc) in dmesg — see kernel/dmesg-avc.txt.\n"
    fi
    if [ "$cam_errors" != "0" ] && [ -n "$cam_errors" ]; then
        warnings="${warnings}- WARNING: ${cam_errors} camera error lines in logcat — see camera/logcat-camera.txt.\n"
    fi
    if [ "$lmk_kills" != "0" ] && [ -n "$lmk_kills" ]; then
        warnings="${warnings}- WARNING: ${lmk_kills} LMK kill lines in dmesg — see kernel/dmesg-lmk.txt.\n"
    fi
    if [ "$refresh_rate" != "n/a" ] && ! printf '%s' "$refresh_rate" | grep -q '^60'; then
        warnings="${warnings}- WARNING: display refresh rate is ${refresh_rate}, not 60 Hz — the 60 Hz pin (P0/P1) is not holding.\n"
    fi
    [ -z "$warnings" ] && warnings="- None: no warnings detected from the collected files.\n"

    {
        printf '# M51 log bundle — %s\n\n' "$M51_TAG"
        printf 'Collected by m51-logger (tools/m51-logger). Read-only collection: nothing was written to system/vendor/boot/recovery.\n\n'
        printf '## Device\n\n'
        printf -- '- Model: %s\n' "$model"
        printf -- '- ROM: %s\n' "$rom"
        printf -- '- Kernel: %s\n' "$kernel"
        printf -- '- Uptime: %s\n' "$uptime"
        printf -- '- SELinux: %s\n' "$selinux_state"
        printf '\n## Headline numbers\n\n'
        printf -- '- Effective swappiness (/proc/sys/vm/swappiness): %s\n' "$swappiness"
        printf -- '- zram disksize (bytes): %s; zram mem used (bytes): %s\n' "$zram_size" "$zram_used"
        printf -- '- Hottest thermal zone: %s C\n' "$max_temp"
        printf -- '- Battery temp (decidegrees C): %s\n' "$battery_temp"
        printf -- '- Display refresh rate: %s\n' "$refresh_rate"
        printf -- '- Free RAM (MemFree): %s\n' "$mem_free"
        printf -- '- LMK kill lines in dmesg: %s\n' "$lmk_kills"
        printf -- '- SELinux denials (avc) in dmesg: %s\n' "$avc_denials"
        printf -- '- Camera error lines in logcat: %s\n' "$cam_errors"
        printf -- '- UN1CA daemons: %s\n' "$daemon_state"
        printf '\n## Warnings\n\n'
        printf '%b' "$warnings"
        printf '\n## How to read this bundle\n\n'
        printf -- '- MANIFEST.txt lists every collector and its status (OK / EMPTY / DENIED / SKIP).\n'
        printf -- '- DENIED or SKIP entries are expected for root-only collectors when the device is not rooted.\n'
        printf -- '- Full logs live in the subfolders (kernel/, system/, camera/, cpu-gpu/, ram/, misc/, recovery/, identity/).\n'
        printf -- '- Attach the whole .tar.gz to a bug report; do not paste logcat inline.\n'
    } > "$out"
}
