#!/usr/bin/env bash
# Copyright (c) 2026 Kartik Deepak Sormare (kkisdevil) — m51-hyperos
# SPDX-License-Identifier: GPL-3.0-or-later
#
# fetch-gsi.sh — download a HyperOS Generic System Image for the m51.
#
# Default: HyperOS 2 (Android 15), Mystic GSI, the safest first try on the
# m51's Android 12 vendor. HyperOS 3 is available with --build.
#
# Known builds (verified against the SourceForge listing on 2026-11-24):
#
#   gold     HyperOS 2 / Android 15, OS3.0.1.0, 2025-12-28, 3.6 GB (default)
#   spring   HyperOS 2 / Android 15, OS2.0.204.0, 2025-12-06, 3.1 GB
#   pudding  HyperOS 3 / Android 16, OS3.0.50.2, 2026-01-22, 4.0 GB (experimental)
#
# Note: the Galaxy A71 HyperOS port used a FoxetGSI build, but the
# FoxetGSI GitHub account returns 404 as of 2026-11-24, so that build is
# NOT listed here — it cannot be downloaded anymore.
#
# Checksums: Mystic GSI publishes NO checksums for these files, so this
# script cannot compare against a publisher checksum. Instead it verifies
# (a) the download came from the expected URL, (b) the size is sane
# against the listed size where one is published, and (c) the archive
# passes an integrity test (unzip -t / 7z t). It records the SHA-256 of
# the downloaded file next to it (<file>.sha256) for future reference.
# Pass --sha256 <hash> to compare against a hash you got from a source
# you trust.
#
# Usage:
#   scripts/fetch-gsi.sh [--build gold|spring|pudding]
#                        [--file NAME] [--url URL] [--out-dir DIR]
#                        [--sha256 HASH] [--extract] [--dry-run] [--list]
#                        [--help]
#
#   --dry-run prints the resolved URL and target path and downloads
#   nothing. --list prints the known builds. --extract also extracts
#   system.img from the archive after verification.
set -euo pipefail

MYSTIC_BASE="https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS"

BUILD="gold"
OUT_DIR="downloads"
DRY_RUN=false
EXTRACT=false
FILE_OVERRIDE=""
URL_OVERRIDE=""
EXPECTED_SHA256=""
LIST_ONLY=false

usage() {
    cat <<'EOF'
Usage: fetch-gsi.sh [options]

Download a HyperOS GSI for the Galaxy M51 (SM-M515F).

Options:
  --build NAME     gold (default, HyperOS 2), spring (HyperOS 2),
                   pudding (HyperOS 3, experimental)
  --file NAME      explicit Mystic GSI filename (overrides --build)
  --url URL        explicit direct download URL (overrides --build/--file)
  --out-dir DIR    download directory (default: downloads/)
  --sha256 HASH    expected SHA-256 of the downloaded file (optional;
                   no publisher checksum exists for these files)
  --extract        also extract system.img from the archive after verifying
  --dry-run        print the resolved URL and target path; download nothing
  --list           print the known builds and exit
  --help           show this help and exit
EOF
}

list_builds() {
    cat <<'EOF'
Known HyperOS GSI builds for the m51 (verified 2026-11-24):

  gold     HyperOS 2 / Android 15 — Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip
           3.6 GB, 2025-12-28, Mystic GSI. DEFAULT — safest first try.
  spring   HyperOS 2 / Android 15 — Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip
           3.1 GB, 2025-12-06, Mystic GSI. Alternative HyperOS 2 build.
  pudding  HyperOS 3 / Android 16 — Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip
           4.0 GB, 2026-01-22, Mystic GSI. EXPERIMENTAL — biggest vendor gap.

Source: https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/
No publisher checksums exist for these files.
EOF
}

# resolve_build <name> — sets FILE, URL, EXPECTED_BYTES (0 = unknown).
resolve_build() {
    local name="$1"
    case "$name" in
        gold)
            FILE="Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip"
            URL="${MYSTIC_BASE}/${FILE}/download"
            EXPECTED_BYTES=3600000000
            ;;
        spring)
            FILE="Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip"
            URL="${MYSTIC_BASE}/${FILE}/download"
            EXPECTED_BYTES=3100000000
            ;;
        pudding)
            FILE="Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip"
            URL="${MYSTIC_BASE}/${FILE}/download"
            EXPECTED_BYTES=4000000000
            ;;
        *)
            echo "Unknown build: $name (see --list)" >&2
            exit 1
            ;;
    esac
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --build)   BUILD="$2"; shift 2 ;;
        --file)    FILE_OVERRIDE="$2"; shift 2 ;;
        --url)     URL_OVERRIDE="$2"; shift 2 ;;
        --out-dir) OUT_DIR="$2"; shift 2 ;;
        --sha256)  EXPECTED_SHA256="$2"; shift 2 ;;
        --extract) EXTRACT=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --list)    LIST_ONLY=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
    esac
done

if $LIST_ONLY; then
    list_builds
    exit 0
fi

# Resolve what to download. Explicit --url wins, then --file, then --build.
if [ -n "$URL_OVERRIDE" ]; then
    URL="$URL_OVERRIDE"
    FILE="$(basename "${URL_OVERRIDE%%\?*}")"
    EXPECTED_BYTES=0
elif [ -n "$FILE_OVERRIDE" ]; then
    FILE="$FILE_OVERRIDE"
    case "$FILE" in
        *.zip|*.7z) ;;
        *) echo "Refusing --file '$FILE': expected a .zip or .7z GSI archive" >&2; exit 1 ;;
    esac
    URL="${MYSTIC_BASE}/${FILE}/download"
    EXPECTED_BYTES=0
else
    resolve_build "$BUILD"
fi

TARGET="${OUT_DIR}/${FILE}"

if $DRY_RUN; then
    echo "build:    ${BUILD}"
    echo "file:     ${FILE}"
    echo "url:      ${URL}"
    echo "target:   ${TARGET}"
    if [ "$EXPECTED_BYTES" -gt 0 ]; then
        echo "size:     ~$((EXPECTED_BYTES / 1000000000)).$(( (EXPECTED_BYTES / 100000000) % 10 )) GB (listed size, approximate)"
    else
        echo "size:     unknown (not published)"
    fi
    echo "checksum: none published by the source; see --sha256"
    echo "dry-run:  nothing downloaded."
    exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "curl is required (install curl)"; exit 1; }
mkdir -p "$OUT_DIR"

echo "Downloading ${FILE} ..."
echo "  from: ${URL}"
echo "  to:   ${TARGET}"
# Resume supported (-C -); 3 retries for transient mirror failures.
curl -L --fail --retry 3 --retry-delay 5 -C - -o "$TARGET" "$URL"

echo "Download finished. Verifying..."

ACTUAL_BYTES="$(stat -c%s "$TARGET")"
echo "  size: ${ACTUAL_BYTES} bytes"
if [ "$EXPECTED_BYTES" -gt 0 ]; then
    # Listed sizes are rounded to 0.1 GB; allow +/-10%.
    LOW=$((EXPECTED_BYTES * 9 / 10))
    HIGH=$((EXPECTED_BYTES * 11 / 10))
    if [ "$ACTUAL_BYTES" -lt "$LOW" ] || [ "$ACTUAL_BYTES" -gt "$HIGH" ]; then
        echo "ERROR: size ${ACTUAL_BYTES} is outside the expected range ${LOW}-${HIGH} for ${FILE} — the download may be incomplete or wrong." >&2
        exit 1
    fi
    echo "  size OK (within 10% of listed size)"
elif [ "$ACTUAL_BYTES" -lt 2000000000 ]; then
    echo "ERROR: ${FILE} is only ${ACTUAL_BYTES} bytes — a real GSI is ~3-5 GB. The download is probably an error page, not the image." >&2
    exit 1
fi

case "$FILE" in
    *.zip)
        command -v unzip >/dev/null 2>&1 || { echo "unzip is required to verify a .zip (install unzip)"; exit 1; }
        echo "  integrity: unzip -t ..."
        unzip -t -q "$TARGET" || { echo "ERROR: zip integrity test failed for ${FILE}" >&2; exit 1; }
        echo "  integrity OK"
        ;;
    *.7z)
        command -v 7z >/dev/null 2>&1 || { echo "7z is required to verify a .7z (install p7zip-full)"; exit 1; }
        echo "  integrity: 7z t ..."
        7z t "$TARGET" >/dev/null || { echo "ERROR: 7z integrity test failed for ${FILE}" >&2; exit 1; }
        echo "  integrity OK"
        ;;
esac

SHA="$(sha256sum "$TARGET" | cut -d' ' -f1)"
echo "$SHA  $FILE" > "${TARGET}.sha256"
echo "  sha256: ${SHA} (recorded in ${TARGET}.sha256)"
if [ -n "$EXPECTED_SHA256" ]; then
    if [ "$SHA" != "$EXPECTED_SHA256" ]; then
        echo "ERROR: SHA-256 mismatch — expected ${EXPECTED_SHA256}, got ${SHA}" >&2
        exit 1
    fi
    echo "  sha256 matches the expected hash"
else
    echo "  NOTE: no publisher checksum exists for this file, so the hash above"
    echo "  was only recorded, not compared. Re-run with --sha256 <hash> to compare."
fi

if $EXTRACT; then
    echo "Extracting system.img from ${FILE} ..."
    case "$FILE" in
        *.zip)
            if ! unzip -o -q "$TARGET" system.img -d "$OUT_DIR" 2>/dev/null; then
                # Some GSI zips nest system.img one directory deep.
                unzip -o -q "$TARGET" '*/system.img' -d "$OUT_DIR" || {
                    echo "ERROR: no system.img found in ${FILE}" >&2; exit 1; }
                mv "${OUT_DIR}"/*/system.img "${OUT_DIR}/system.img"
            fi
            ;;
        *.7z)
            (cd "$OUT_DIR" && 7z x -y "$FILE" system.img >/dev/null) || {
                echo "ERROR: no system.img found in ${FILE}" >&2; exit 1; }
            ;;
    esac
    IMG_BYTES="$(stat -c%s "${OUT_DIR}/system.img")"
    if [ "$IMG_BYTES" -lt 1000000000 ]; then
        echo "ERROR: extracted system.img is only ${IMG_BYTES} bytes — not a real system image." >&2
        exit 1
    fi
    echo "  system.img: ${OUT_DIR}/system.img (${IMG_BYTES} bytes)"
fi

echo "Done: ${TARGET}"
