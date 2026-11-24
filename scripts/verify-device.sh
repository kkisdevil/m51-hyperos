#!/usr/bin/env bash
# Copyright (c) 2026 Kartik Deepak Sormare (kkisdevil) — m51-hyperos
# SPDX-License-Identifier: GPL-3.0-or-later
#
# verify-device.sh — go / no-go prerequisite check for HyperOS on the m51.
#
# Talks to the attached phone over adb and checks the things the GSI route
# needs: the right model, an unlocked bootloader, Treble, and dynamic
# partitions. Informational checks (VNDK version, kernel, TWRP, super
# size, free space) are reported but never fail the run on their own.
#
# Exit codes:
#   0  all critical checks passed (go)
#   1  a critical check failed (no-go)
#   2  adb is missing or no device is attached/authorized
#
# Usage:
#   scripts/verify-device.sh [--device SERIAL] [--strict] [--help]
#
#   --device SERIAL  check a specific device when several are attached
#   --strict         treat UNKNOWN on a critical check as a failure
#   --help           show this help and exit
#
# No device attached is a clean failure (exit 2), never a crash.
set -u

DEVICE=""
STRICT=false

usage() {
    cat <<'EOF'
Usage: verify-device.sh [options]

Check whether the attached phone is ready for the HyperOS GSI route.

Options:
  --device SERIAL  check a specific device (see `adb devices`)
  --strict         treat UNKNOWN on a critical check as a failure
  --help           show this help and exit

Exit codes: 0 = go, 1 = no-go (a critical check failed),
2 = adb missing or no device attached/authorized.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --device) DEVICE="$2"; shift 2 ;;
        --strict) STRICT=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
    esac
done

PASS_COUNT=0
FAIL_COUNT=0
UNKNOWN_COUNT=0

# report <severity: critical|info> <status: PASS|FAIL|UNKNOWN> <name> <detail>
report() {
    local severity="$1" status="$2" name="$3" detail="$4"
    printf '[%s] %-28s %s\n' "$status" "$name" "$detail"
    case "$status" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        FAIL)
            FAIL_COUNT=$((FAIL_COUNT + 1))
            ;;
        UNKNOWN)
            UNKNOWN_COUNT=$((UNKNOWN_COUNT + 1))
            if $STRICT && [ "$severity" = "critical" ]; then
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
            ;;
    esac
}

# adb_cmd <args...> — run adb (with -s if a device was given), print stdout.
adb_cmd() {
    if [ -n "$DEVICE" ]; then
        adb -s "$DEVICE" "$@"
    else
        adb "$@"
    fi
}

# prop <name> — getprop value, empty on any failure.
prop() {
    adb_cmd shell getprop "$1" 2>/dev/null | tr -d '\r' || true
}

echo "m51-hyperos device check"
echo "========================"

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: adb is not installed (install Android platform-tools)." >&2
    exit 2
fi

# --- device attached? -------------------------------------------------
DEVICES="$(adb_cmd devices 2>/dev/null | awk 'NR > 1 && NF >= 2 {print $1, $2}')"
if [ -z "$DEVICES" ]; then
    echo "ERROR: no device attached (adb devices is empty)." >&2
    echo "Connect the phone with USB debugging on and try again." >&2
    exit 2
fi
# A line ending in " device" means an attached, authorized device.
if ! printf '%s\n' "$DEVICES" | grep -q ' device$'; then
    echo "ERROR: a device is connected but not in 'device' state:" >&2
    printf '%s\n' "$DEVICES" >&2
    echo "Authorize the PC on the phone (tap Allow on the RSA prompt) and retry." >&2
    exit 2
fi
SERIAL="$(printf '%s\n' "$DEVICES" | grep ' device$' | head -n1 | cut -d' ' -f1)"
if [ -n "$DEVICE" ]; then
    SERIAL="$DEVICE"
fi
echo "device: $SERIAL"
echo

# --- critical checks ---------------------------------------------------
MODEL="$(prop ro.product.model)"
if [ "$MODEL" = "SM-M515F" ]; then
    report critical PASS "model" "SM-M515F"
else
    report critical FAIL "model" "got '${MODEL:-<empty>}' — this guide is for the SM-M515F only"
fi

CODENAME="$(prop ro.product.device)"
if [ "$CODENAME" = "m51" ]; then
    report critical PASS "codename" "m51"
else
    report critical FAIL "codename" "got '${CODENAME:-<empty>}' — expected m51"
fi

LOCKED="$(prop ro.boot.flash.locked)"
VBMETA_STATE="$(prop ro.boot.vbmeta.device_state)"
if [ "$LOCKED" = "0" ] || [ "$VBMETA_STATE" = "unlocked" ]; then
    report critical PASS "bootloader unlocked" "flash.locked=${LOCKED:-?} vbmeta=${VBMETA_STATE:-?}"
elif [ "$LOCKED" = "1" ] || [ "$VBMETA_STATE" = "locked" ]; then
    report critical FAIL "bootloader unlocked" "bootloader is LOCKED — unlock it first (this wipes the phone)"
else
    report critical UNKNOWN "bootloader unlocked" "could not read flash.locked / vbmeta.device_state — check in Download mode"
fi

TREBLE="$(prop ro.treble.enabled)"
if [ "$TREBLE" = "true" ]; then
    report critical PASS "Treble enabled" "ro.treble.enabled=true"
else
    report critical FAIL "Treble enabled" "got '${TREBLE:-<empty>}' — a GSI needs Treble"
fi

DYN="$(prop ro.boot.dynamic_partitions)"
if [ "$DYN" = "true" ]; then
    report critical PASS "dynamic partitions" "ro.boot.dynamic_partitions=true"
else
    report critical FAIL "dynamic partitions" "got '${DYN:-<empty>}' — DSU and fastbootd flashing need dynamic partitions"
fi

# --- informational checks ----------------------------------------------
VNDK="$(prop ro.vndk.version)"
if [ "$VNDK" = "31" ]; then
    report info PASS "vendor VNDK" "31 (Android 12 vendor — HyperOS 2 first, not HyperOS 3)"
elif [ -n "$VNDK" ]; then
    report info UNKNOWN "vendor VNDK" "got ${VNDK}, expected 31 — a different vendor than the guides assume"
else
    report info UNKNOWN "vendor VNDK" "could not read ro.vndk.version"
fi

KERNEL="$(adb_cmd shell uname -r 2>/dev/null | tr -d '\r' || true)"
case "$KERNEL" in
    4.14*) report info PASS "kernel" "$KERNEL (4.14 as expected for the m51)" ;;
    "")    report info UNKNOWN "kernel" "could not read kernel version" ;;
    *)      report info UNKNOWN "kernel" "got $KERNEL — not the stock 4.14 kernel" ;;
esac

TWRP_VER="$(prop ro.twrp.version)"
if [ -n "$TWRP_VER" ]; then
    report info PASS "TWRP present" "version $TWRP_VER (phone is in recovery)"
else
    report info UNKNOWN "TWRP present" "cannot confirm from the running system — boot to recovery and check (full flash needs it; DSU trial does not)"
fi

SUPER_BYTES="$(adb_cmd shell blockdev --getsize64 /dev/block/by-name/super 2>/dev/null | tr -d '\r' || true)"
if [ -n "$SUPER_BYTES" ] && [ "$SUPER_BYTES" -gt 0 ] 2>/dev/null; then
    SUPER_GB=$((SUPER_BYTES / 1000000000))
    if [ "$SUPER_BYTES" -ge 7500000000 ]; then
        report info PASS "super partition" "${SUPER_GB} GB (room for the ~3-4 GB system image)"
    else
        report info UNKNOWN "super partition" "only ${SUPER_GB} GB — the GSI may not fit; check the flash guide"
    fi
else
    report info UNKNOWN "super partition" "could not read super size (needs shell access to the block device)"
fi

DATA_FREE_KB="$(adb_cmd shell df -k /data 2>/dev/null | awk 'NR==2 {print $4}' | tr -d '\r' || true)"
if [ -n "$DATA_FREE_KB" ] && [ "$DATA_FREE_KB" -gt 0 ] 2>/dev/null; then
    DATA_FREE_GB=$((DATA_FREE_KB / 1000000))
    if [ "$DATA_FREE_GB" -ge 8 ]; then
        report info PASS "free space on /data" "${DATA_FREE_GB} GB free (>= 8 GB recommended for a DSU trial)"
    else
        report info UNKNOWN "free space on /data" "only ${DATA_FREE_GB} GB free — free space before a DSU trial"
    fi
else
    report info UNKNOWN "free space on /data" "could not read free space"
fi

# --- summary ------------------------------------------------------------
echo
echo "----------------------------------------"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT  UNKNOWN: $UNKNOWN_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "Result: NO-GO — fix the failed checks above, then re-run."
    exit 1
fi
echo "Result: GO — the phone meets the GSI prerequisites."
echo "Next: try the DSU trial boot (docs/dsu-trial.md) before any flash."
exit 0
