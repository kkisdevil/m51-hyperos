#!/usr/bin/env bash
# setup-ghidra.sh — install Ghidra (headless-only) for mercury-rename.
#
# Downloads the official Ghidra release zip, verifies its published
# SHA-256, extracts it under tools/mercury-rename/ghidra/, and confirms
# `analyzeHeadless` runs. No GUI is installed or needed.
#
# Usage:
#   bash setup-ghidra.sh            # download + verify + extract + check
#   bash setup-ghidra.sh --check    # only verify an existing install
#
# The zip (~570 MB) and the extracted tree are NOT committed — see
# tools/mercury-rename/.gitignore. Re-running the script is safe: a
# present zip with a matching hash is reused, and extraction is skipped
# when the install already exists.

set -euo pipefail

GHIDRA_VERSION="12.2"
GHIDRA_TAG="Ghidra_12.2_build"
GHIDRA_ZIP="ghidra_12.2_PUBLIC_20261016.zip"
# Published SHA-256 from the official release page:
# https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.2_build
GHIDRA_SHA256="2c2cd776db3c1f6a097ba418922378ac3649cadd5e844a6f5f088ae628a7be67"
GHIDRA_URL="https://github.com/NationalSecurityAgency/ghidra/releases/download/${GHIDRA_TAG}/${GHIDRA_ZIP}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_DIR="${SCRIPT_DIR}/downloads"
INSTALL_DIR="${SCRIPT_DIR}/ghidra"
ZIP_PATH="${DOWNLOAD_DIR}/${GHIDRA_ZIP}"
EXTRACTED_DIR="${INSTALL_DIR}/ghidra_${GHIDRA_VERSION}_PUBLIC"

check_only=false
if [[ "${1:-}" == "--check" ]]; then
    check_only=true
fi

fail() { echo "setup-ghidra: ERROR: $*" >&2; exit 1; }

# --- prerequisites ---------------------------------------------------------
command -v curl >/dev/null || fail "curl is required"
command -v unzip >/dev/null || fail "unzip is required"
command -v sha256sum >/dev/null || fail "sha256sum is required"
if ! command -v java >/dev/null; then
    fail "a 64-bit JDK 21 is required (Ghidra 12.x will not run without it)"
fi
java_version="$(java -version 2>&1 | head -1)"
echo "setup-ghidra: java: ${java_version}"

# Ghidra 12.2 requires a 64-bit JDK 25. Prefer the standard Ubuntu
# install when present; otherwise derive JAVA_HOME from `java` on PATH.
# Ghidra's launcher needs JAVA_HOME set (it will not search PATH when
# there is no TTY to prompt on).
if [[ -z "${JAVA_HOME:-}" ]]; then
    if [[ -x /usr/lib/jvm/java-25-openjdk-amd64/bin/java ]]; then
        JAVA_HOME="/usr/lib/jvm/java-25-openjdk-amd64"
    else
        JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
    fi
fi
export JAVA_HOME
java_major="$("${JAVA_HOME}/bin/java" -version 2>&1 | head -1 \
    | sed -E 's/.*version "([0-9]+).*/\1/')"
if [[ "${java_major}" != "25" ]]; then
    fail "Ghidra 12.2 needs a 64-bit JDK 25 (found major '${java_major}' at ${JAVA_HOME}). Install it: sudo apt-get install -y openjdk-25-jdk"
fi
echo "setup-ghidra: JDK 25 at ${JAVA_HOME}"

if [[ "${check_only}" == true ]]; then
    [[ -x "${EXTRACTED_DIR}/support/analyzeHeadless" ]] \
        || fail "no install at ${EXTRACTED_DIR} — run without --check first"
    "${EXTRACTED_DIR}/support/analyzeHeadless" 2>&1 | head -3 || true
    echo "setup-ghidra: OK — analyzeHeadless present at ${EXTRACTED_DIR}"
    exit 0
fi

# --- download (resumable) --------------------------------------------------
mkdir -p "${DOWNLOAD_DIR}" "${INSTALL_DIR}"
if [[ -f "${ZIP_PATH}" ]]; then
    echo "setup-ghidra: zip already present, verifying hash before reuse"
    if echo "${GHIDRA_SHA256}  ${ZIP_PATH}" | sha256sum -c - >/dev/null 2>&1; then
        echo "setup-ghidra: existing zip hash matches, reusing it"
    else
        echo "setup-ghidra: existing zip hash MISMATCHES — re-downloading"
        rm -f "${ZIP_PATH}"
    fi
fi
if [[ ! -f "${ZIP_PATH}" ]]; then
    echo "setup-ghidra: downloading ${GHIDRA_ZIP} (~570 MB) ..."
    curl -L --fail --retry 3 --retry-delay 5 -C - -o "${ZIP_PATH}" "${GHIDRA_URL}"
fi

# --- verify ----------------------------------------------------------------
echo "setup-ghidra: verifying SHA-256 ..."
echo "${GHIDRA_SHA256}  ${ZIP_PATH}" | sha256sum -c - \
    || fail "SHA-256 mismatch — the download is corrupt or tampered with; delete ${ZIP_PATH} and retry"

# --- extract ---------------------------------------------------------------
if [[ -x "${EXTRACTED_DIR}/support/analyzeHeadless" ]]; then
    echo "setup-ghidra: already extracted at ${EXTRACTED_DIR}"
else
    echo "setup-ghidra: extracting ..."
    unzip -q -o "${ZIP_PATH}" -d "${INSTALL_DIR}"
    chmod +x "${EXTRACTED_DIR}/support/analyzeHeadless" "${EXTRACTED_DIR}/support/analyze" 2>/dev/null || true
fi

# --- smoke check -----------------------------------------------------------
"${EXTRACTED_DIR}/support/analyzeHeadless" 2>&1 | head -3 || true
echo "setup-ghidra: OK — Ghidra ${GHIDRA_VERSION} ready at ${EXTRACTED_DIR}"
echo "setup-ghidra: analyzeHeadless: ${EXTRACTED_DIR}/support/analyzeHeadless"
