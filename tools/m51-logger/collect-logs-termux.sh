#!/usr/bin/env bash
# m51-logger — on-device collector for the Galaxy M51 (SM-M515F).
#
# Same collection as collect-logs.sh, run from the phone itself inside
# Termux. No PC needed: everything is read locally and written to
# /sdcard/yuzora-logs/<bundle>/ (or $HOME/yuzora-logs/ when the
# sdcard is not writable), then packed as a tar.gz with MANIFEST.txt
# + SUMMARY.md.
#
# Usage (in Termux):
#   bash collect-logs-termux.sh [--out <dir>] [--no-tar] [--skip-logcat]
#
# READ-ONLY: only local reads. No writes to system/vendor/boot/recovery,
# no flashing, no recovery overwrite (TWRP rule). Root-only collectors
# are skipped (recorded as SKIP) when `su` is unavailable; if the
# phone is rooted, `su -c id` is probed once and root collectors run
# through it. Full `logcat -d` needs root (or READ_LOGS) — without
# root, logcat shows only this UID's lines; that limitation is
# recorded in MANIFEST.txt, not hidden.
#
# Prefer running this locally rather than over wireless ADB: a local
# run binds nothing to the network, while an always-listening adbd on
# 0.0.0.0:5555 is reachable from the hotspot LAN (see
# docs/LOGGING-GUIDE.md, "Always-on ADB").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$SCRIPT_DIR/lib/collect-core.sh"

OUT_BASE="/sdcard/yuzora-logs"
[ -w /sdcard ] || OUT_BASE="$HOME/yuzora-logs"
DO_TAR=1
SKIP_LOGCAT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --out)     OUT_BASE="$2"; shift 2 ;;
        --no-tar)  DO_TAR=0; shift ;;
        --skip-logcat) SKIP_LOGCAT=1; shift ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

[ -f "$CORE" ] || { echo "missing core lib: $CORE" >&2; exit 1; }

M51_HAS_SU=0
if su -c id 2>/dev/null | grep -q 'uid=0'; then
    M51_HAS_SU=1
    echo "root available (su works) — root collectors enabled"
else
    echo "no root — root-only collectors will be SKIPped (see MANIFEST.txt)"
fi

TAG="m51-logs-$(date +%Y%m%d-%H%M%S)"
M51_OUT="$OUT_BASE/$TAG"
mkdir -p "$M51_OUT"
export M51_OUT M51_HAS_SU
M51_TAG="$TAG"
export M51_TAG

# Runner functions required by the core lib: local shell, one process
# per collector, no network, no ADB reconnect at all.
local_run()    { sh -c "$1"; }
local_run_su() { su -c "$1"; }
M51_RUN=local_run
M51_RUN_SU=local_run_su
export M51_RUN M51_RUN_SU

# shellcheck source=lib/collect-core.sh
source "$CORE"

if [ "$SKIP_LOGCAT" = "1" ]; then
    echo "skipping logcat collectors (--skip-logcat)"
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
