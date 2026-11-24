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

rm -rf "$WORK"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ]
