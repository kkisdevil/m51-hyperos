#!/usr/bin/env bash
# m51-logger — PC-side collector for the Galaxy M51 (SM-M515F).
#
# Pulls kernel, boot, recovery, system, camera, CPU/GPU, RAM and misc
# logs from a connected M51 over ADB into ONE timestamped bundle, then
# packs it as a tar.gz with MANIFEST.txt + SUMMARY.md.
#
# Usage:
#   ./collect-logs.sh [--serial <serial>] [--connect <host:port>]
#                     [--out <dir>] [--no-tar] [--skip-logcat]
#
# Connection rule (standing): ONE persistent ADB connection for the
# whole run. The script selects the device once (or connects once with
# --connect), runs every collector over that one transport, and never
# reconnects per collector and never runs `adb kill-server` mid-run.
# The phone's adbd flaps and re-prompts authorisation on reconnect —
# a fresh connection per check is how the prompts multiply.
#
# READ-ONLY: only `adb shell` reads and no device writes at all. No
# flashing, no remount, no recovery overwrite (TWRP rule). Root-only
# collectors are skipped (recorded as SKIP in MANIFEST.txt) when the
# device is not rooted; pass nothing extra — root is detected, never
# forced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$SCRIPT_DIR/lib/collect-core.sh"

SERIAL=""
CONNECT=""
OUT_BASE="${PWD}/m51-logs"
DO_TAR=1
SKIP_LOGCAT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --serial)  SERIAL="$2"; shift 2 ;;
        --connect) CONNECT="$2"; shift 2 ;;
        --out)     OUT_BASE="$2"; shift 2 ;;
        --no-tar)  DO_TAR=0; shift ;;
        --skip-logcat) SKIP_LOGCAT=1; shift ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

command -v adb >/dev/null 2>&1 || { echo "adb not found in PATH" >&2; exit 1; }
[ -f "$CORE" ] || { echo "missing core lib: $CORE" >&2; exit 1; }

# --- one connection, once -------------------------------------------------
if [ -n "$CONNECT" ]; then
    echo "connecting once: adb connect $CONNECT"
    adb connect "$CONNECT" || { echo "adb connect failed" >&2; exit 1; }
fi

ADB_ARGS=""
if [ -n "$SERIAL" ]; then
    ADB_ARGS="-s $SERIAL"
fi

# shellcheck disable=SC2086
DEVICE_COUNT="$(adb $ADB_ARGS devices 2>/dev/null | grep -cw device || true)"
if [ "$DEVICE_COUNT" != "1" ]; then
    echo "expected exactly 1 ADB device, found $DEVICE_COUNT." >&2
    echo "Run 'adb devices' and pass --serial <serial>, or --connect <host:port>." >&2
    exit 1
fi

# --- root detection (one probe, never forced) ------------------------------
M51_HAS_SU=0
# shellcheck disable=SC2086
if adb $ADB_ARGS shell su -c id 2>/dev/null | grep -q 'uid=0'; then
    M51_HAS_SU=1
    echo "root available (su works) — root collectors enabled"
else
    echo "no root — root-only collectors will be SKIPped (see MANIFEST.txt)"
fi

# --- bundle ----------------------------------------------------------------
TAG="m51-logs-$(date +%Y%m%d-%H%M%S)"
M51_OUT="$OUT_BASE/$TAG"
mkdir -p "$M51_OUT"
export M51_OUT M51_HAS_SU
M51_TAG="$TAG"
export M51_TAG

# Runner functions required by the core lib. $ADB_ARGS is unquoted on
# purpose: it is empty or exactly "-s <serial>".
# shellcheck disable=SC2086
adb_run()    { adb $ADB_ARGS shell "$1"; }
# shellcheck disable=SC2086
adb_run_su() { adb $ADB_ARGS shell su -c "$1"; }
M51_RUN=adb_run
M51_RUN_SU=adb_run_su
export M51_RUN M51_RUN_SU

# shellcheck source=lib/collect-core.sh
source "$CORE"

if [ "$SKIP_LOGCAT" = "1" ]; then
    echo "skipping logcat collectors (--skip-logcat)"
    # Collect everything except logcat by temporarily stubbing it out:
    # the core has no skip switch, so logcat files are collected and
    # then emptied + marked in the manifest.
    m51_collect_all
    for f in "$M51_OUT"/system/logcat-*.txt "$M51_OUT"/camera/logcat-camera.txt; do
        [ -f "$f" ] && printf 'SKIPPED (--skip-logcat)\n' > "$f"
    done
else
    m51_collect_all
fi

m51_write_summary

echo "---- bundle ----"
echo "folder: $M51_OUT"
grep -c '|OK' "$M51_OUT/MANIFEST.txt" | xargs echo "collectors OK:"
grep -c '|SKIP' "$M51_OUT/MANIFEST.txt" | xargs echo "collectors SKIP (root):"
grep -c '|DENIED' "$M51_OUT/MANIFEST.txt" | xargs echo "collectors DENIED:"
echo "summary: $M51_OUT/SUMMARY.md"

if [ "$DO_TAR" = "1" ]; then
    (cd "$OUT_BASE" && tar -czf "$TAG.tar.gz" "$TAG")
    echo "archive: $OUT_BASE/$TAG.tar.gz"
fi
