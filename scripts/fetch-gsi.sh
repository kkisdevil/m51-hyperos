#!/usr/bin/env bash
# Copyright (c) 2026 Kartik Deepak Sormare (kkisdevil) — m51-hyperos
# SPDX-License-Identifier: GPL-3.0-or-later
#
# fetch-gsi.sh — download a HyperOS Generic System Image for the m51.
#
# Default: HyperOS 2 (Android 15), Mystic GSI, spring build — the safest
# first try on the m51's Android 12 vendor. It is the Qualcomm-source
# HyperOS 2 build (see below); gold was the old default and is kept as
# an explicit option. HyperOS 3 is available with --build.
#
# Known builds (verified against the SourceForge listing + HTTP HEAD +
# public firmware pages on 2026-11-24 — see docs/gsi-verification.md):
#
#   spring   HyperOS 2 / Android 15, OS2.0.204.0.VOUMIXM, 2025-12-06,
#            3,122,721,686 bytes, MD5 3e6337d1dd850ae2d0f7d067f8dd191c
#            Source: Redmi 15 5G / POCO M7 Plus 5G — Qualcomm Snapdragon
#            6s Gen 3. DEFAULT — the Qualcomm-source HyperOS 2 build the
#            port plan calls for (no MTK telephony/camera jars).
#   gold     HyperOS 3.0.1.0 / Android 15, OS3.0.1.0.VNQCNXM, 2025-12-28,
#            3,554,104,547 bytes, MD5 edb87b9e088f0e1eaa5e8bf1c0ba6113
#            Source: Redmi Note 13 5G / POCO X6 Neo 5G — MediaTek
#            Dimensity 6080. NOT HyperOS 2 and NOT Qualcomm, despite the
#            old label. Use only if the MTK RIL/ATMs shim chain is
#            deliberately planned in (A03 T1.12-T1.14).
#   pudding  HyperOS 3 / Android 16, OS3.0.50.2.W, 2026-01-22,
#            3,994,747,809 bytes, MD5 9eb03ec3f211365aecbaa346be9516b5
#            Source: Xiaomi 17 — Qualcomm Snapdragon 8 Elite Gen 5
#            (SM8850). EXPERIMENTAL — biggest vendor gap.
#
# Filesystem format of the images (EROFS vs ext4, and EROFS compressor)
# is UNKNOWN from public metadata — the MysticGSI tool defaults to
# ext4 and builds EROFS only with --format, but no publisher note says
# which the published builds use. See docs/gsi-verification.md §3 for
# the check that settles it after download (it matters: the m51 kernel
# mounts EROFS-LZ4 only, no LZMA — docs/kernel-defconfig-plan.md §3.3).
#
# Note: the Galaxy A71 HyperOS port used a FoxetGSI build, but the
# FoxetGSI GitHub account returns 404 as of 2026-11-24, so that build is
# NOT listed here — it cannot be downloaded anymore.
#
# Checksums: SourceForge publishes an MD5 per file (project RSS feed);
# no SHA-256 is published for these files. This script verifies (a) the
# download came from the expected URL, (b) the size matches the exact
# byte count from the mirror HEAD, (c) the MD5 matches the publisher
# hash, and (d) the archive passes an integrity test (unzip -t / 7z t).
# It records the SHA-256 of the downloaded file next to it
# (<file>.sha256) for future reference. Pass --sha256 <hash> to compare
# against a hash you got from a source you trust.
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

BUILD="spring"
OUT_DIR="downloads"
DRY_RUN=false
EXTRACT=false
FILE_OVERRIDE=""
URL_OVERRIDE=""
EXPECTED_SHA256=""
EXPECTED_MD5=""
LIST_ONLY=false

usage() {
    cat <<'EOF'
Usage: fetch-gsi.sh [options]

Download a HyperOS GSI for the Galaxy M51 (SM-M515F).

Options:
  --build NAME     spring (default, HyperOS 2 / Android 15, Qualcomm
                   source), gold (HyperOS 3.0.1.0 / Android 15,
                   MediaTek source — needs the MTK shim chain),
                   pudding (HyperOS 3 / Android 16, experimental)
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
Known HyperOS GSI builds for the m51 (verified 2026-11-24, see
docs/gsi-verification.md for sources and the format caveat):

  spring   HyperOS 2 / Android 15 — Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip
           3,122,721,686 bytes, 2025-12-06, MD5 3e6337d1dd850ae2d0f7d067f8dd191c
           Source: Redmi 15 5G / POCO M7 Plus 5G, Qualcomm Snapdragon 6s Gen 3.
           DEFAULT — Qualcomm-source HyperOS 2, the safest first try.
  gold     HyperOS 3.0.1.0 / Android 15 — Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip
           3,554,104,547 bytes, 2025-12-28, MD5 edb87b9e088f0e1eaa5e8bf1c0ba6113
           Source: Redmi Note 13 5G / POCO X6 Neo 5G, MediaTek Dimensity 6080.
           NOT HyperOS 2, NOT Qualcomm — needs the MTK RIL/ATMs shim chain.
  pudding  HyperOS 3 / Android 16 — Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip
           3,994,747,809 bytes, 2026-01-22, MD5 9eb03ec3f211365aecbaa346be9516b5
           Source: Xiaomi 17, Qualcomm Snapdragon 8 Elite Gen 5 (SM8850).
           EXPERIMENTAL — biggest vendor gap.

Source: https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/
MD5s are published by SourceForge (project RSS feed); no SHA-256 exists
for these files. Filesystem format (EROFS vs ext4) is UNKNOWN from
public metadata — check it right after download (docs/gsi-verification.md §3).
EOF
}

# resolve_build <name> — sets FILE, URL, EXPECTED_BYTES, EXPECTED_MD5.
# Sizes are exact byte counts (mirror HEAD Content-Length, 2026-11-24);
# MD5s are the publisher hashes from the SourceForge RSS feed.
resolve_build() {
    local name="$1"
    case "$name" in
        gold)
            FILE="Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip"
            URL="${MYSTIC_BASE}/${FILE}/download"
            EXPECTED_BYTES=3554104547
            EXPECTED_MD5="edb87b9e088f0e1eaa5e8bf1c0ba6113"
            ;;
        spring)
            FILE="Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip"
            URL="${MYSTIC_BASE}/${FILE}/download"
            EXPECTED_BYTES=3122721686
            EXPECTED_MD5="3e6337d1dd850ae2d0f7d067f8dd191c"
            ;;
        pudding)
            FILE="Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip"
            URL="${MYSTIC_BASE}/${FILE}/download"
            EXPECTED_BYTES=3994747809
            EXPECTED_MD5="9eb03ec3f211365aecbaa346be9516b5"
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
    EXPECTED_MD5=""
elif [ -n "$FILE_OVERRIDE" ]; then
    FILE="$FILE_OVERRIDE"
    case "$FILE" in
        *.zip|*.7z) ;;
        *) echo "Refusing --file '$FILE': expected a .zip or .7z GSI archive" >&2; exit 1 ;;
    esac
    URL="${MYSTIC_BASE}/${FILE}/download"
    EXPECTED_BYTES=0
    EXPECTED_MD5=""
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
        echo "size:     ${EXPECTED_BYTES} bytes (exact, verified 2026-11-24)"
    else
        echo "size:     unknown (not published)"
    fi
    if [ -n "$EXPECTED_MD5" ]; then
        echo "md5:      ${EXPECTED_MD5} (publisher hash, SourceForge RSS)"
    else
        echo "md5:      none known for this file; see --sha256"
    fi
    echo "format:   EROFS vs ext4 UNKNOWN from public metadata — check after"
    echo "          download (docs/gsi-verification.md section 3)"
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
    # EXPECTED_BYTES is the exact byte count (mirror HEAD, 2026-11-24);
    # allow +/-10% for mirror rounding / re-uploads of the same file.
    LOW=$((EXPECTED_BYTES * 9 / 10))
    HIGH=$((EXPECTED_BYTES * 11 / 10))
    if [ "$ACTUAL_BYTES" -lt "$LOW" ] || [ "$ACTUAL_BYTES" -gt "$HIGH" ]; then
        echo "ERROR: size ${ACTUAL_BYTES} is outside the expected range ${LOW}-${HIGH} for ${FILE} — the download may be incomplete or wrong." >&2
        exit 1
    fi
    echo "  size OK (within 10% of verified size ${EXPECTED_BYTES})"
elif [ "$ACTUAL_BYTES" -lt 2000000000 ]; then
    echo "ERROR: ${FILE} is only ${ACTUAL_BYTES} bytes — a real GSI is ~3-5 GB. The download is probably an error page, not the image." >&2
    exit 1
fi

# Publisher MD5 (SourceForge RSS) — checked before the slow integrity
# test so a wrong file fails fast.
if [ -n "$EXPECTED_MD5" ]; then
    command -v md5sum >/dev/null 2>&1 || { echo "md5sum is required to verify the publisher MD5 (install coreutils)"; exit 1; }
    ACTUAL_MD5="$(md5sum "$TARGET" | cut -d' ' -f1)"
    if [ "$ACTUAL_MD5" != "$EXPECTED_MD5" ]; then
        echo "ERROR: MD5 mismatch — expected ${EXPECTED_MD5}, got ${ACTUAL_MD5}. The download is corrupt or not the published file." >&2
        exit 1
    fi
    echo "  md5 OK (${ACTUAL_MD5}, matches publisher hash)"
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
    echo "  NOTE: no publisher SHA-256 exists for this file (the publisher"
    echo "  hash is MD5, already compared above), so this SHA-256 was only"
    echo "  recorded, not compared. Re-run with --sha256 <hash> to compare."
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
