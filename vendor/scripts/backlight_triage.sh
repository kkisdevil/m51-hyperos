#!/usr/bin/env bash
# backlight_triage.sh — black-screen triage for the m51 panel (HyperOS port).
#
# Our own implementation of the fix from Arnav3078/OneOS-SM7150 commit
# fb7fb18 (2026-11-23, "resolve black screen boot by unblanking panel0
# backlight"), Apache-2.0, credited in vendor/README.md. The measured
# facts from that commit, applied here as a diagnostic first:
#
# - The panel node is /sys/class/backlight/panel0-backlight, NOT
#   /sys/class/backlight/panel. Code that only knows "panel" misses it.
# - Check actual_brightness, not just brightness: the guest/system can
#   report brightness != 0 while actual_brightness = 0 — the panel is
#   actually dark.
# - Unblank bl_power (echo 0) before touching brightness: a powered-down
#   backlight ignores brightness writes.
# - Early unblank value: max_brightness * 180 / 425 (floor 50).
# - The sysfs range is 0..13510 (max_brightness), NOT 0..255 — the
#   Android 0-255 scale is not the sysfs range (see
#   docs/reverse-engineering.md §3 row 8, corrected 2026-11-24).
#
# Usage (report only by default — reads sysfs, writes nothing):
#     bash backlight_triage.sh [--sysfs /sys] [--fix]
#   --fix writes bl_power=0 and the early-unblank brightness value.
#   Only use --fix on the device, after reading the report.
#
# Exit codes: 0 panel looks lit / fix applied, 1 panel looks dark
# (or no panel node found), 2 bad usage.

set -u

SYSFS="/sys"
FIX=false

while [ $# -gt 0 ]; do
  case "$1" in
    --sysfs) SYSFS="$2"; shift 2 ;;
    --fix)   FIX=true; shift ;;
    --help|-h)
      sed -n '1,20p' "$0" | sed 's/^# //;s/^#//'
      exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Candidate panel nodes, in the order fb7fb18 probed them.
CANDIDATES="panel0-backlight panel
  /sys/class/lcd/panel/panel
  /sys/class/lcd/panel/device/backlight/panel
  /sys/class/leds/lcd-backlight"

find_node() {
  for c in $CANDIDATES; do
    case "$c" in
      /*) [ -d "$SYSFS$c" ] && { echo "$SYSFS$c"; return 0; } ;;
      *)  [ -d "$SYSFS/class/backlight/$c" ] && { echo "$SYSFS/class/backlight/$c"; return 0; } ;;
    esac
  done
  return 1
}

read_num() { # file -> number or empty
  [ -r "$1" ] || { echo ""; return 1; }
  tr -dc '0-9' < "$1"
}

NODE="$(find_node)" || {
  echo "FAIL: no backlight node found under $SYSFS"
  echo "  probed: panel0-backlight, panel, lcd/panel, lcd-backlight"
  exit 1
}
echo "panel node: $NODE"

BRIGHTNESS="$(read_num "$NODE/brightness" || true)"
ACTUAL="$(read_num "$NODE/actual_brightness" || true)"
BL_POWER="$(read_num "$NODE/bl_power" || true)"
MAX="$(read_num "$NODE/max_brightness" || true)"
[ -n "$MAX" ] || MAX=13510

echo "brightness:        ${BRIGHTNESS:-<unreadable>}"
echo "actual_brightness: ${ACTUAL:-<unreadable>}"
echo "bl_power:          ${BL_POWER:-<unreadable>} (0 = unblanked)"
echo "max_brightness:    $MAX (sysfs range 0..$MAX, not 0..255)"

DARK=0
[ -n "$BL_POWER" ] && [ "$BL_POWER" != "0" ] && {
  echo "DIAGNOSIS: bl_power is $BL_POWER — backlight is powered down;"
  echo "  brightness writes are ignored until it is unblanked."
  DARK=1
}
[ -n "$ACTUAL" ] && [ "$ACTUAL" = "0" ] && {
  echo "DIAGNOSIS: actual_brightness is 0 — the panel is dark even if"
  echo "  brightness reads non-zero (brightness lies; actual_brightness"
  echo "  is the truth)."
  DARK=1
}

if [ "$FIX" = true ]; then
  echo 0 > "$NODE/bl_power" 2>/dev/null || {
    echo "error: cannot write $NODE/bl_power (need root / writable sysfs)" >&2
    exit 1
  }
  EARLY=$(( MAX * 180 / 425 ))
  [ "$EARLY" -lt 50 ] && EARLY=50
  echo "$EARLY" > "$NODE/brightness" 2>/dev/null || {
    echo "error: cannot write $NODE/brightness" >&2
    exit 1
  }
  echo "fix applied: bl_power=0, brightness=$EARLY (max*180/425, floor 50)"
  exit 0
fi

if [ "$DARK" = 1 ]; then
  echo "RESULT: panel looks DARK — run with --fix to unblank it, or check"
  echo "  the lights HAL / composer before touching anything else."
  exit 1
fi
echo "RESULT: panel looks lit (bl_power=0, actual_brightness non-zero)."
exit 0
