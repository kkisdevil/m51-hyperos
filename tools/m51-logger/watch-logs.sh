#!/usr/bin/env bash
# m51-logger — live log watcher, PC side (Galaxy M51, SM-M515F).
#
# Streams ALL logcat buffers continuously and SAVES them. One session
# dir per device connection — i.e. one per boot attempt. A phone that
# bootloops produces one file per attempt, so no attempt's logs are
# ever overwritten by the next one. At every connect it also snapshots
# dmesg, getprop and the DSU state.
#
# This is the tool for the HyperOS GSI boot: start it BEFORE the DSU
# boot, let it run while the GSI tries to come up, stop it after. If
# the GSI never reaches adb, the pstore snapshot from the next
# collect-logs.sh run (or from TWRP) is the only record — the watcher
# cannot invent logs from a device that never talks.
#
# Usage:
#   ./watch-logs.sh [--serial <serial>] [--connect <host:port>]
#                   [--out <dir>] [--max-mb <n>] [--keep <n>]
#                   [--duration <seconds>]
#
#   --serial   adb device serial (default: the only attached device)
#   --connect  wireless ADB host:port, e.g. 127.0.0.1:5555 (default:
#              USB / whatever adb already sees)
#   --out      where sessions are saved (default: ./m51-logs-live)
#   --max-mb   roll to a new part file after this many MB in one
#              session file (default: 100; a roll loses <1s of logs
#              and the gap is written in watcher.log)
#   --keep     keep only the newest N session dirs, prune older ones
#              (default: 0 = keep everything)
#   --duration stop by itself after N seconds (default: 0 = run until
#              stopped)
#
# Stop it with: Ctrl-C, --duration, or `touch <out>/STOP`.
#
# Connection rule (standing): ONE adb server for the whole run. The
# watcher never runs `adb kill-server` and never reconnects per
# collector — it waits on the same server (`adb wait-for-device`)
# and re-uses the authorised connection. With --connect it re-issues
# the same `adb connect` each cycle (the authorisation key persists,
# so it does not re-prompt).
#
# READ-ONLY: only `adb shell` reads and one streaming `adb logcat`.
# No writes to the device, no flashing, no recovery overwrite
# (TWRP rule). Root-only snapshots (full dmesg) are best-effort: when
# the device is not rooted they record UNAVAILABLE instead of failing.
set -euo pipefail

SERIAL=""
CONNECT=""
OUT_BASE="${PWD}/m51-logs-live"
MAX_MB=100
KEEP=0
DURATION=0

while [ $# -gt 0 ]; do
    case "$1" in
        --serial)   SERIAL="$2"; shift 2 ;;
        --connect)  CONNECT="$2"; shift 2 ;;
        --out)      OUT_BASE="$2"; shift 2 ;;
        --max-mb)   MAX_MB="$2"; shift 2 ;;
        --keep)     KEEP="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,40p' "$0"
            exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

command -v adb >/dev/null 2>&1 || { echo "adb not found in PATH" >&2; exit 1; }
case "$MAX_MB$KEEP$DURATION" in
    *[!0-9]*) echo "--max-mb/--keep/--duration must be non-negative integers" >&2; exit 2 ;;
esac

ADB=(adb)
if [ -n "$SERIAL" ]; then
    ADB+=(-s "$SERIAL")
fi
MAX_BYTES=$((MAX_MB * 1024 * 1024))

mkdir -p "$OUT_BASE"
WATCHER_LOG="$OUT_BASE/watcher.log"
STOP_FILE="$OUT_BASE/STOP"
START_TS="$(date +%s)"
STOPPING=0

log_msg() { # log_msg <text> — timestamped line in watcher.log + stdout
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S %Z') $1"
    printf '%s\n' "$line" | tee -a "$WATCHER_LOG"
}

write_readme() {
    cat > "$OUT_BASE/WATCHER-README.md" <<'EOF'
# Live log watcher — how to read this folder

`watch-logs.sh` was running here. Each `session-*/` dir is one device
connection — one boot attempt. A bootloop leaves one dir per attempt.

- `logcat-all.txt` (or `logcat-all-partN.txt` when a session rolled
  past --max-mb): the full live logcat, threadtime format, buffers
  main + system + radio + events + crash. Grep it first.
- `dmesg.txt`: kernel log snapshot taken at connect (UNAVAILABLE when
  the device is not rooted).
- `getprop.txt`: all properties at connect.
- `dsu-state.txt`: `dumpsys dynamic_system` at connect (DSU trial
  state; UNAVAILABLE when the service does not exist on the build).
- `watcher.log`: session start/end, rotations, gaps, stop reason.

Useful greps (run from this folder):

```sh
grep -ri 'MiuiLightsService\|lights' session-*/logcat-all*.txt
grep -ri 'FingerprintService\|libbauthserver\|no fingerprint hardware' session-*/logcat-all*.txt
grep -ri 'avc:.*denied' session-*/logcat-all*.txt
grep -ri 'FATAL EXCEPTION\|Boot loop\|system_server.*died' session-*/logcat-all*.txt
grep -ri 'RIL\|rild' session-*/logcat-all*.txt
```

`latest` is a symlink to the newest session dir.
EOF
}

# Ask the watcher to stop from another shell: touch <out>/STOP.
# Ctrl-C / SIGTERM also stop it cleanly (trap below).
finish() {
    STOPPING=1
}
trap finish INT TERM

# Wait until the device is reachable on the same adb server.
# Returns 0 once the device is up, 1 if stopping was requested.
wait_device() {
    while [ "$STOPPING" = "0" ]; do
        if [ -f "$STOP_FILE" ]; then
            return 1
        fi
        if [ -n "$CONNECT" ]; then
            "${ADB[@]}" connect "$CONNECT" >> "$WATCHER_LOG" 2>&1 || true
        fi
        if command -v timeout >/dev/null 2>&1; then
            if timeout 30 "${ADB[@]}" wait-for-device >> "$WATCHER_LOG" 2>&1; then
                return 0
            fi
        else
            if "${ADB[@]}" wait-for-device >> "$WATCHER_LOG" 2>&1; then
                return 0
            fi
        fi
        sleep 2
    done
    return 1
}

# True while the logcat PID is alive (a zombie counts as dead).
logcat_alive() {
    local pid="$1" state=""
    if ! kill -0 "$pid" 2>/dev/null; then
        return 1
    fi
    if [ -r "/proc/$pid/stat" ]; then
        state="$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null || echo "")"
        if [ "$state" = "Z" ]; then
            return 1
        fi
    fi
    return 0
}

# Stop the run when --duration elapsed or the STOP file appeared.
should_stop() {
    local now elapsed
    if [ -f "$STOP_FILE" ]; then
        return 0
    fi
    if [ "$DURATION" -gt 0 ]; then
        now="$(date +%s)"
        elapsed=$((now - START_TS))
        if [ "$elapsed" -ge "$DURATION" ]; then
            return 0
        fi
    fi
    if [ "$STOPPING" = "1" ]; then
        return 0
    fi
    return 1
}

prune_old_sessions() {
    local count oldest
    if [ "$KEEP" -le 0 ]; then
        return 0
    fi
    count="$(find "$OUT_BASE" -maxdepth 1 -type d -name 'session-*' | wc -l)"
    while [ "$count" -gt "$KEEP" ]; do
        oldest="$(find "$OUT_BASE" -maxdepth 1 -type d -name 'session-*' -printf '%T@ %p\n' 2>/dev/null | sort -n | head -n1 | cut -d' ' -f2-)"
        if [ -z "$oldest" ]; then
            return 0
        fi
        rm -rf "$oldest"
        log_msg "pruned old session (keep=$KEEP): $oldest"
        count=$((count - 1))
    done
}

write_readme
: > "$WATCHER_LOG"
log_msg "watcher started: out=$OUT_BASE max-mb=$MAX_MB keep=$KEEP duration=$DURATION serial=${SERIAL:-<any>} connect=${CONNECT:-<usb>}"

SESSION_N=0
while true; do
    if should_stop; then
        break
    fi
    if ! wait_device; then
        break
    fi
    SESSION_N=$((SESSION_N + 1))
    SESS_DIR="$OUT_BASE/session-$(date +%Y%m%d-%H%M%S)-$SESSION_N"
    mkdir -p "$SESS_DIR"
    ln -sfn "$SESS_DIR" "$OUT_BASE/latest"
    log_msg "session $SESSION_N started: $SESS_DIR"

    # Connect-time snapshots (best effort, never fatal).
    if ! "${ADB[@]}" shell dmesg > "$SESS_DIR/dmesg.txt" 2>/dev/null; then
        printf 'UNAVAILABLE (not rooted or dmesg denied)\n' > "$SESS_DIR/dmesg.txt"
    fi
    if ! "${ADB[@]}" shell getprop > "$SESS_DIR/getprop.txt" 2>/dev/null; then
        printf 'UNAVAILABLE\n' > "$SESS_DIR/getprop.txt"
    fi
    if ! "${ADB[@]}" shell dumpsys dynamic_system > "$SESS_DIR/dsu-state.txt" 2>/dev/null; then
        printf 'UNAVAILABLE (no dynamic_system service on this build)\n' > "$SESS_DIR/dsu-state.txt"
    fi

    # Stream logcat for this session; roll the file past --max-mb.
    PART=1
    CUR_LOG="$SESS_DIR/logcat-all.txt"
    "${ADB[@]}" logcat -v threadtime -b main -b system -b radio -b events -b crash > "$CUR_LOG" 2> "$SESS_DIR/logcat.err" &
    LOGCAT_PID=$!
    while logcat_alive "$LOGCAT_PID"; do
        sleep 2
        if should_stop; then
            kill "$LOGCAT_PID" 2>/dev/null || true
            break
        fi
        if [ "$MAX_BYTES" -gt 0 ]; then
            SIZE="$(stat -c %s "$CUR_LOG" 2>/dev/null || echo 0)"
            if [ "$SIZE" -ge "$MAX_BYTES" ]; then
                kill "$LOGCAT_PID" 2>/dev/null || true
                wait "$LOGCAT_PID" 2>/dev/null || true
                PART=$((PART + 1))
                CUR_LOG="$SESS_DIR/logcat-all-part$PART.txt"
                log_msg "session $SESSION_N: rolled logcat to part $PART at ${MAX_MB} MB (gap <1s possible)"
                "${ADB[@]}" logcat -v threadtime -b main -b system -b radio -b events -b crash > "$CUR_LOG" 2>> "$SESS_DIR/logcat.err" &
                LOGCAT_PID=$!
            fi
        fi
    done
    wait "$LOGCAT_PID" 2>/dev/null || true
    if should_stop; then
        log_msg "session $SESSION_N ended: watcher stopping"
    else
        log_msg "session $SESSION_N ended: device disconnected or logcat stopped"
    fi
    prune_old_sessions
    sleep 2
done

END_TS="$(date +%s)"
log_msg "watcher stopped after $((END_TS - START_TS))s, $SESSION_N session(s) in $OUT_BASE"
echo "sessions: $OUT_BASE (see watcher.log)"
