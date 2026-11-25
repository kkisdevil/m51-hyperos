#!/usr/bin/env bash
# m51-logger — live log watcher, on-device in Termux (Galaxy M51).
#
# Same idea as watch-logs.sh, but running on the phone itself: logcat
# writes straight to files with its own rotation, plus a dmesg poller
# when root is available. Use this for logging the RUNNING system
# (UN1CA runtime, lag sessions, LMK kills) — it keeps recording with
# no PC attached.
#
# It does NOT cover a GSI boot: booting the GSI replaces the system
# Termux runs in, so the on-device watcher dies with it. For the DSU
# trial use the PC-side watch-logs.sh, started before the boot.
#
# Usage (in Termux):
#   bash watch-logs-termux.sh start [--out <dir>] [--size-kb <n>]
#                                   [--count <n>] [--dmesg-interval <s>]
#   bash watch-logs-termux.sh stop
#   bash watch-logs-termux.sh status
#
#   --size-kb        KB per rotated logcat file (default: 4096)
#   --count          rotated files to keep (default: 20)
#   --dmesg-interval seconds between dmesg snapshots (default: 60;
#                    0 = off). Needs root; without root it records
#                    SKIP and the poller does not start.
#
# Files: <out>/live-logcat.txt[.1, .2, ...] (logcat -f rotation),
# <out>/dmesg-live.txt (latest snapshot), <out>/watcher.pid.
# Stop: `bash watch-logs-termux.sh stop` or `touch <out>/STOP`.
#
# NOTE: without root, logcat shows only this app's own lines. One-time
# fix from a PC (once, it survives reboots):
#   adb shell pm grant com.termux android.permission.READ_LOGS
# With root, everything is visible. The watcher records which case
# applies in watcher.log — it never hides the limitation.
set -euo pipefail

OUT_BASE="/sdcard/yuzora-logs/live"
[ -w /sdcard ] || OUT_BASE="$HOME/yuzora-logs/live"
SIZE_KB=4096
COUNT=20
DMESG_INTERVAL=60
CMD="${1:-status}"
if [ "$CMD" = "start" ] || [ "$CMD" = "stop" ] || [ "$CMD" = "status" ]; then
    shift || true
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --out)            OUT_BASE="$2"; shift 2 ;;
        --size-kb)        SIZE_KB="$2"; shift 2 ;;
        --count)          COUNT="$2"; shift 2 ;;
        --dmesg-interval) DMESG_INTERVAL="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,30p' "$0"
            exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$SIZE_KB$COUNT$DMESG_INTERVAL" in
    *[!0-9]*) echo "--size-kb/--count/--dmesg-interval must be non-negative integers" >&2; exit 2 ;;
esac

mkdir -p "$OUT_BASE"
PID_FILE="$OUT_BASE/watcher.pid"
LOG_FILE="$OUT_BASE/watcher.log"

log_msg() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$1" | tee -a "$LOG_FILE"
}

has_su() {
    su -c id 2>/dev/null | grep -q 'uid=0'
}

cmd_status() {
    if [ -f "$PID_FILE" ]; then
        local alive=0 pid
        while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                alive=$((alive + 1))
                printf 'running: pid %s (%s)\n' "$pid" "$(ps -o comm= -p "$pid" 2>/dev/null || echo '?')"
            fi
        done < "$PID_FILE"
        if [ "$alive" = "0" ]; then
            echo "watcher not running (stale pid file)"
        fi
    else
        echo "watcher not running"
    fi
    if [ -f "$OUT_BASE/live-logcat.txt" ]; then
        ls -la "$OUT_BASE"/live-logcat.txt* 2>/dev/null
    fi
}

cmd_stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "watcher not running (no pid file)"
        exit 0
    fi
    touch "$OUT_BASE/STOP"
    local pid
    while read -r pid; do
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
    done < "$PID_FILE"
    sleep 2
    while read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE" "$OUT_BASE/STOP"
    log_msg "watcher stopped"
    echo "watcher stopped"
}

cmd_start() {
    if [ -f "$PID_FILE" ] && grep -q . "$PID_FILE"; then
        if kill -0 "$(head -n1 "$PID_FILE")" 2>/dev/null; then
            echo "watcher already running (see status); stop it first" >&2
            exit 1
        fi
    fi
    rm -f "$OUT_BASE/STOP"
    : > "$LOG_FILE"
    if has_su; then
        log_msg "root available — full logcat + dmesg poller enabled"
    else
        log_msg "no root — logcat shows only this UID's lines unless READ_LOGS was granted (adb shell pm grant com.termux android.permission.READ_LOGS)"
    fi
    # logcat -f rotates by itself: live-logcat.txt, .1, .2, ...
    logcat -f "$OUT_BASE/live-logcat.txt" -r "$SIZE_KB" -n "$COUNT" -v threadtime -b all >> "$LOG_FILE" 2>&1 &
    echo "$!" > "$PID_FILE"
    log_msg "logcat watcher started (pid $!, ${SIZE_KB} KB x ${COUNT} files)"
    if [ "$DMESG_INTERVAL" -gt 0 ]; then
        if has_su; then
            (
                while [ ! -f "$OUT_BASE/STOP" ]; do
                    su -c dmesg > "$OUT_BASE/dmesg-live.txt" 2>/dev/null || echo "UNAVAILABLE" > "$OUT_BASE/dmesg-live.txt"
                    sleep "$DMESG_INTERVAL"
                done
            ) &
            echo "$!" >> "$PID_FILE"
            log_msg "dmesg poller started (pid $!, every ${DMESG_INTERVAL}s)"
        else
            printf 'SKIP (no root)\n' > "$OUT_BASE/dmesg-live.txt"
            log_msg "dmesg poller SKIP (no root)"
        fi
    fi
    echo "watcher running in $OUT_BASE (logcat -f, ${SIZE_KB} KB x ${COUNT})"
    echo "stop with: bash $0 stop"
}

case "$CMD" in
    start)  cmd_start ;;
    stop)   cmd_stop ;;
    status) cmd_status ;;
    *) echo "usage: $0 {start|stop|status} [--out <dir>] ..." >&2; exit 2 ;;
esac
