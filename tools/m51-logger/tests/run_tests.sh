#!/usr/bin/env bash
# m51-logger dry-run tests — no phone needed.
# Runs collect-logs.sh against the mock adb (tests/mock-adb) with two
# fixture sets (bad: swappiness 100 + hot + denials; good: clean) and
# asserts the bundle, MANIFEST, SUMMARY warnings and tar.gz.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGGER_DIR="$(dirname "$TESTS_DIR")"
WORK="$(mktemp -d)"
# Expose the mock as `adb` on PATH (the file itself stays named mock-adb).
mkdir -p "$WORK/bin"
ln -s "$TESTS_DIR/mock-adb" "$WORK/bin/adb"
export PATH="$WORK/bin:$PATH"
PASS=0; FAIL=0

check() { # check <name> <command...>
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1)); printf 'PASS: %s\n' "$name"
    else
        FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$name"
    fi
}
check_contains() { # check_contains <name> <file> <pattern>
    local name="$1" file="$2" pat="$3"
    if [ -f "$file" ] && grep -qE "$pat" "$file"; then
        PASS=$((PASS + 1)); printf 'PASS: %s\n' "$name"
    else
        FAIL=$((FAIL + 1)); printf 'FAIL: %s (file=%s, pattern=%s)\n' "$name" "$file" "$pat"
    fi
}
check_absent() { # check_absent <name> <file> <pattern>
    local name="$1" file="$2" pat="$3"
    if [ -f "$file" ] && ! grep -qE "$pat" "$file"; then
        PASS=$((PASS + 1)); printf 'PASS: %s\n' "$name"
    else
        FAIL=$((FAIL + 1)); printf 'FAIL: %s (file=%s, pattern=%s)\n' "$name" "$file" "$pat"
    fi
}

run_case() { # run_case <label> <fixture-dir> <out-dir>
    local label="$1" fixture="$2" out="$3"
    printf 'running case: %s\n' "$label" >&2
    export MOCK_FIXTURES="$fixture"
    bash "$LOGGER_DIR/collect-logs.sh" --out "$out" >/dev/null 2>&1
    local bundle
    bundle="$(find "$out" -maxdepth 1 -type d -name 'm51-logs-*' | head -n1)"
    printf '%s' "$bundle"
}

# ---- bad device -----------------------------------------------------------
BAD_OUT="$WORK/bad"
BAD_BUNDLE="$(run_case bad "$TESTS_DIR/fixtures/bad" "$BAD_OUT")"
check "bad: bundle dir exists" test -d "$BAD_BUNDLE"
check "bad: tar.gz exists" test -f "$BAD_OUT/$(basename "$BAD_BUNDLE").tar.gz"
check "bad: MANIFEST exists" test -s "$BAD_BUNDLE/MANIFEST.txt"
check "bad: SUMMARY exists" test -s "$BAD_BUNDLE/SUMMARY.md"
check_contains "bad: SUMMARY names the model" "$BAD_BUNDLE/SUMMARY.md" 'SM-M515F'
check_contains "bad: SUMMARY names the ROM" "$BAD_BUNDLE/SUMMARY.md" 'UN1CA 5\.4\.0'
check_contains "bad: SUMMARY names the kernel" "$BAD_BUNDLE/SUMMARY.md" '4\.14\.357-openela'
check_contains "bad: SUMMARY shows effective swappiness 100" "$BAD_BUNDLE/SUMMARY.md" 'swappiness.*100'
check_contains "bad: SUMMARY warns swappiness != 60" "$BAD_BUNDLE/SUMMARY.md" 'WARNING: effective swappiness is 100'
check_contains "bad: SUMMARY warns hottest zone > 45C" "$BAD_BUNDLE/SUMMARY.md" 'WARNING: hottest thermal zone is 52 C'
check_contains "bad: SUMMARY warns SELinux denials" "$BAD_BUNDLE/SUMMARY.md" 'WARNING: 2 SELinux denials'
check_contains "bad: SUMMARY warns camera errors" "$BAD_BUNDLE/SUMMARY.md" 'WARNING: 2 camera error lines'
check_contains "bad: SUMMARY warns LMK kills" "$BAD_BUNDLE/SUMMARY.md" 'WARNING: 1 LMK kill lines'
check_contains "bad: MANIFEST records logcat OK" "$BAD_BUNDLE/MANIFEST.txt" 'system/logcat-all.txt\|OK'
check_contains "bad: MANIFEST records swappiness OK" "$BAD_BUNDLE/MANIFEST.txt" 'ram/swappiness.txt\|OK'
check_contains "bad: MANIFEST records thermal OK" "$BAD_BUNDLE/MANIFEST.txt" 'cpu-gpu/thermal-zone-temps.txt\|OK'
check_contains "bad: daemon state in SUMMARY" "$BAD_BUNDLE/SUMMARY.md" 'carbon_power_engine RUNNING'
check_contains "bad: refresh rate 60 in SUMMARY" "$BAD_BUNDLE/SUMMARY.md" 'refresh rate: 60\.00 Hz'

# ---- good device ----------------------------------------------------------
GOOD_OUT="$WORK/good"
GOOD_BUNDLE="$(run_case good "$TESTS_DIR/fixtures/good" "$GOOD_OUT")"
check "good: bundle dir exists" test -d "$GOOD_BUNDLE"
check_contains "good: SUMMARY shows swappiness 60" "$GOOD_BUNDLE/SUMMARY.md" 'swappiness.*60'
check_absent "good: no swappiness warning" "$GOOD_BUNDLE/SUMMARY.md" 'WARNING: effective swappiness'
check_absent "good: no thermal warning" "$GOOD_BUNDLE/SUMMARY.md" 'WARNING: hottest thermal zone'
check_absent "good: no SELinux warning" "$GOOD_BUNDLE/SUMMARY.md" 'WARNING: .* SELinux denials'
check_absent "good: no camera warning" "$GOOD_BUNDLE/SUMMARY.md" 'WARNING: .* camera error'
check_contains "good: SUMMARY says no warnings" "$GOOD_BUNDLE/SUMMARY.md" 'no warnings detected'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"

# ---- watcher (live logcat sessions) ---------------------------------------
# Uses its own PASS/FAIL tally; the script exits non-zero if either the
# collector cases or the watcher checks failed.
WPASS=0; WFAIL=0
wcheck() { # wcheck <name> <command...>
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        WPASS=$((WPASS + 1)); printf 'PASS: %s\n' "$name"
    else
        WFAIL=$((WFAIL + 1)); printf 'FAIL: %s\n' "$name"
    fi
}

WATCH_OUT="$WORK/watch"
# The collector cases above leave MOCK_FIXTURES pointing at the good
# fixtures (which lack logcat/dmesg/getprop files) — point it back at
# the bad fixtures, which have all of them.
export MOCK_FIXTURES="$TESTS_DIR/fixtures/bad"
# Run A — reconnect loop: the mock logcat emits ~3 MB then exits, so
# with --max-mb 5 no rotation happens and each exit starts a new
# session (one per boot attempt, as on a bootlooping device).
bash "$LOGGER_DIR/watch-logs.sh" --out "$WATCH_OUT" --duration 20 --max-mb 5 >/dev/null 2>&1
WATCH_SESSIONS="$(find "$WATCH_OUT" -maxdepth 1 -type d -name 'session-*' | wc -l)"
wcheck "watch: at least 2 sessions (reconnect loop)" test "$WATCH_SESSIONS" -ge 2
wcheck "watch: watcher.log exists" test -s "$WATCH_OUT/watcher.log"
wcheck "watch: watcher.log records a session start" grep -qE 'session 1 started' "$WATCH_OUT/watcher.log"
wcheck "watch: WATCHER-README exists" test -s "$WATCH_OUT/WATCHER-README.md"
wcheck "watch: latest symlink exists" test -L "$WATCH_OUT/latest"
FIRST_SESSION="$(find "$WATCH_OUT" -maxdepth 1 -type d -name 'session-*' | sort | head -n1)"
wcheck "watch: session has logcat file" test -s "$FIRST_SESSION/logcat-all.txt"
wcheck "watch: session has dmesg snapshot" test -s "$FIRST_SESSION/dmesg.txt"
wcheck "watch: session has getprop snapshot" test -s "$FIRST_SESSION/getprop.txt"
wcheck "watch: session has dsu-state snapshot" test -s "$FIRST_SESSION/dsu-state.txt"
# Run B — rotation: with --max-mb 1 the same ~3 MB stream must roll
# to a second part file inside one session.
WATCH_ROT_OUT="$WORK/watch-rot"
bash "$LOGGER_DIR/watch-logs.sh" --out "$WATCH_ROT_OUT" --duration 12 --max-mb 1 >/dev/null 2>&1
ROT_SESSION="$(find "$WATCH_ROT_OUT" -maxdepth 1 -type d -name 'session-*' | sort | head -n1)"
wcheck "watch-rot: watcher.log records a rotation" grep -qE 'rolled logcat to part 2' "$WATCH_ROT_OUT/watcher.log"
wcheck "watch-rot: session rolled to part 2" test -s "$ROT_SESSION/logcat-all-part2.txt"

# STOP file stops the watcher.
WATCH_STOP_OUT="$WORK/watch-stop"
bash "$LOGGER_DIR/watch-logs.sh" --out "$WATCH_STOP_OUT" --duration 0 >/dev/null 2>&1 &
WATCH_PID=$!
sleep 4
touch "$WATCH_STOP_OUT/STOP"
STOPPED=0
for _ in $(seq 1 15); do
    if ! kill -0 "$WATCH_PID" 2>/dev/null; then STOPPED=1; break; fi
    sleep 1
done
if [ "$STOPPED" = "0" ]; then
    kill "$WATCH_PID" 2>/dev/null || true
    wait "$WATCH_PID" 2>/dev/null || true
fi
wcheck "watch: exits on STOP file" test "$STOPPED" = "1"
wcheck "watch-stop: watcher.log records the stop" grep -qE 'watcher stopped' "$WATCH_STOP_OUT/watcher.log"

printf '\nwatcher: %d passed, %d failed\n' "$WPASS" "$WFAIL"
rm -rf "$WORK"
[ "$FAIL" = "0" ] && [ "$WFAIL" = "0" ]
