#!/bin/bash
# upload-gsi-drive.sh — mirror the spring HyperOS GSI to Google Drive.
#
# The Drive CLI cannot multipart-upload multi-GB files (Google 500 on
# the single 3.1 GB upload, twice). Same fix as the firmware mirror:
# split into 1 GiB parts, upload each part separately with
# `hatch_gws_cli drive +upload`, verify every part on Drive by
# size + md5Checksum, then confirm the folder total.
#
# Usage: bash scripts/upload-gsi-drive.sh
# Logs to downloads/gsi-drive-upload.log (IST timestamps, levels,
# stages — same format as firmware.log via scripts/firmware-logger.sh).
# Idempotent: parts already on Drive with the same name+size are skipped.
# A part that fails twice stops the run (exit non-zero) — do not claim
# a mirror exists until the folder listing confirms it.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/firmware-logger.sh"

GSI_FILE="Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip"
GSI_DIR="$HOME/workspace/m51-hyperos/downloads"
ZIP_PATH="$GSI_DIR/$GSI_FILE"
GWS_CLI="${GWS_CLI:-/opt/hatch/bin/hatch_gws_cli}"
DRIVE_PARENT_NAME="${DRIVE_PARENT_NAME:-m51-hyperos}"
DRIVE_FOLDER_NAME="${DRIVE_FOLDER_NAME:-gsi}"
CHUNK_BYTES="${CHUNK_BYTES:-1073741824}"   # 1 GiB split parts

# Expected values (verified 2026-11-24, re-verified before this run).
EXPECT_SIZE=3122721686
EXPECT_MD5="3e6337d1dd850ae2d0f7d067f8dd191c"
EXPECT_SHA256="ed6c670ab9f7eb87dfbd713d348809a6546c130f83b8799cc9fac1b5acd1a03d"

FW_LOG_FILE="$GSI_DIR/gsi-drive-upload.log"
export FW_LOG_FILE
mkdir -p "$GSI_DIR"

fail() { fw_error "$1" "$2"; exit 1; }

# ------------------------------------------------------------------
# 1. verify local zip
# ------------------------------------------------------------------
fw_section "1. verify local GSI zip"
[ -f "$ZIP_PATH" ] || fail verify "GSI zip missing" path="$ZIP_PATH"
SIZE="$(stat -c %s "$ZIP_PATH")"
[ "$SIZE" -eq "$EXPECT_SIZE" ] || fail verify "zip size mismatch" bytes="$SIZE" expected="$EXPECT_SIZE"
MD5="$(md5sum "$ZIP_PATH" | awk '{print $1}')"
SHA256="$(sha256sum "$ZIP_PATH" | awk '{print $1}')"
[ "$MD5" = "$EXPECT_MD5" ] || fail verify "MD5 mismatch — STOP, do not upload a bad file" md5="$MD5" expected="$EXPECT_MD5"
[ "$SHA256" = "$EXPECT_SHA256" ] || fail verify "SHA-256 mismatch — STOP" sha256="$SHA256" expected="$EXPECT_SHA256"
fw_log INFO verify "local zip verified" path="$ZIP_PATH" bytes="$SIZE" md5="$MD5" sha256="$SHA256"

# ------------------------------------------------------------------
# 2. drive (chunked — the CLI cannot multipart-upload multi-GB files)
# ------------------------------------------------------------------
fw_section "2. drive upload (chunked, 1 GiB parts)"
fw_log INFO drive "resolving parent folder" name="$DRIVE_PARENT_NAME"
PARENT_JSON="$("$GWS_CLI" drive files list --params "{\"q\":\"name = '$DRIVE_PARENT_NAME' and mimeType = 'application/vnd.google-apps.folder' and trashed=false\",\"pageSize\":5,\"fields\":\"files(id,name)\"}" 2>&1)" \
    || fail drive "could not list Drive folders" error="$PARENT_JSON"
PARENT_ID="$(echo "$PARENT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['files'][0]['id'] if d.get('files') else '')" 2>/dev/null)"
[ -n "$PARENT_ID" ] || fail drive "Drive folder not found" name="$DRIVE_PARENT_NAME"
fw_log INFO drive "parent folder resolved" name="$DRIVE_PARENT_NAME" folder_id="$PARENT_ID" source="backups/m51-hyperos"

# GSI subfolder (create if missing).
SUB_JSON="$("$GWS_CLI" drive files list --params "{\"q\":\"name = '$DRIVE_FOLDER_NAME' and '$PARENT_ID' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed=false\",\"pageSize\":5,\"fields\":\"files(id,name)\"}" 2>&1)"
SUB_ID="$(echo "$SUB_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['files'][0]['id'] if d.get('files') else '')" 2>/dev/null)"
if [ -z "$SUB_ID" ]; then
    SUB_JSON="$("$GWS_CLI" drive files create --params '{"ignoreDefaultVisibility":true}' --json "{\"name\":\"$DRIVE_FOLDER_NAME\",\"mimeType\":\"application/vnd.google-apps.folder\",\"parents\":[\"$PARENT_ID\"]}" 2>&1)" \
        || fail drive "could not create gsi folder" error="$SUB_JSON"
    SUB_ID="$(echo "$SUB_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)"
    fw_log INFO drive "created gsi folder" name="$DRIVE_FOLDER_NAME" folder_id="$SUB_ID" parent="$PARENT_ID"
else
    fw_log INFO drive "gsi folder exists" name="$DRIVE_FOLDER_NAME" folder_id="$SUB_ID"
fi

# Split (idempotent: split is cheap and deterministic).
SPLIT_DIR="$GSI_DIR/split"
mkdir -p "$SPLIT_DIR"
fw_log INFO drive "splitting zip into 1 GiB parts" chunk_bytes="$CHUNK_BYTES" out_dir="$SPLIT_DIR"
split -b "$CHUNK_BYTES" -d --suffix-length=2 "$ZIP_PATH" "$SPLIT_DIR/$GSI_FILE.part" \
    || fail drive "split failed"
N_PARTS="$(find "$SPLIT_DIR" -maxdepth 1 -type f -name "$GSI_FILE.part*" | wc -l)"
fw_log INFO drive "split complete" parts="$N_PARTS"

upload_one_part() {
    local part="$1" pname="$2" pbytes="$3" pmd5="$4"
    local attempt
    for attempt in 1 2; do
        fw_log INFO drive "uploading part" part="$pname" bytes="$pbytes" md5="$pmd5" attempt="$attempt" method="hatch_gws_cli drive +upload (multipart, single part)"
        U_START=$(date +%s)
        UP_JSON="$("$GWS_CLI" drive +upload "$part" --parent "$SUB_ID" --name "$pname" 2>&1)"
        RC=$?
        U_END=$(date +%s)
        if [ "$RC" -ne 0 ]; then
            fw_log ERROR drive "upload attempt failed" part="$pname" attempt="$attempt" exit="$RC" duration_s="$((U_END - U_START))" error="$UP_JSON"
            continue
        fi
        UP_ID="$(echo "$UP_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)"
        GOT="$("$GWS_CLI" drive files get --params "{\"fileId\":\"$UP_ID\",\"fields\":\"id,name,size,md5Checksum,webViewLink\"}" 2>&1)"
        G_SIZE="$(echo "$GOT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('size',''))" 2>/dev/null)"
        G_MD5="$(echo "$GOT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('md5Checksum',''))" 2>/dev/null)"
        if [ "$G_SIZE" = "$pbytes" ] && [ "$G_MD5" = "$pmd5" ]; then
            fw_log INFO drive "part verified on Drive" part="$pname" bytes="$G_SIZE" md5="$G_MD5" duration_s="$((U_END - U_START))" file_id="$UP_ID"
            echo "$UP_ID"
            return 0
        fi
        fw_log ERROR drive "part verification FAILED (size/md5 mismatch)" part="$pname" attempt="$attempt" drive_size="$G_SIZE" local_size="$pbytes" drive_md5="$G_MD5" local_md5="$pmd5"
    done
    return 1
}

for part in "$SPLIT_DIR"/"$GSI_FILE".part*; do
    pname="$(basename "$part")"
    pbytes="$(stat -c %s "$part")"
    pmd5="$(md5sum "$part" | awk '{print $1}')"
    # Skip parts already on Drive with the same name+size.
    EXIST="$("$GWS_CLI" drive files list --params "{\"q\":\"name = '$pname' and '$SUB_ID' in parents and trashed=false\",\"pageSize\":5,\"fields\":\"files(id,name,size,md5Checksum)\"}" 2>&1)"
    E_SIZE="$(echo "$EXIST" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['files'][0].get('size','') if d.get('files') else '')" 2>/dev/null)"
    E_ID="$(echo "$EXIST" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['files'][0].get('id','') if d.get('files') else '')" 2>/dev/null)"
    if [ -n "$E_SIZE" ] && [ "$E_SIZE" = "$pbytes" ]; then
        fw_log INFO drive "part already on Drive, skipping" part="$pname" bytes="$pbytes" file_id="$E_ID"
        continue
    fi
    upload_one_part "$part" "$pname" "$pbytes" "$pmd5" \
        || fail drive "part upload failed twice — STOPPING" part="$pname"
done
fw_log INFO drive "all parts uploaded and verified" folder="backups/m51-hyperos/gsi" parts="$N_PARTS"

# Folder listing total check.
LIST_JSON="$("$GWS_CLI" drive files list --params "{\"q\":\"'$SUB_ID' in parents and trashed=false\",\"pageSize\":50,\"fields\":\"files(id,name,size,md5Checksum)\"}" 2>&1)" \
    || fail drive "folder listing failed" error="$LIST_JSON"
TOTAL="$(echo "$LIST_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
parts=[f for f in d.get('files',[]) if f['name'].startswith('$GSI_FILE.part')]
print(sum(int(f['size']) for f in parts))
for f in sorted(parts,key=lambda x:x['name']): print(f['name'],f['size'],f.get('md5Checksum',''),f['id'])
" 2>/dev/null)"
TOTAL_BYTES="$(echo "$TOTAL" | head -1)"
if [ "$TOTAL_BYTES" = "$EXPECT_SIZE" ]; then
    fw_log INFO drive "folder listing confirms all parts on Drive" total_bytes="$TOTAL_BYTES" expected_bytes="$EXPECT_SIZE" match=true parts="$N_PARTS" folder="backups/m51-hyperos/gsi" folder_id="$SUB_ID"
    echo "$TOTAL" | tail -n +2 | while read -r nm sz md fid; do
        fw_log INFO drive "part on Drive" part="$nm" bytes="$sz" md5="$md" file_id="$fid"
    done
else
    fail drive "folder total MISMATCH" total_bytes="$TOTAL_BYTES" expected_bytes="$EXPECT_SIZE"
fi

# ------------------------------------------------------------------
# 3. README / rejoin note
# ------------------------------------------------------------------
fw_section "3. rejoin note"
README_PATH="$GSI_DIR/GSI-README.txt"
{
    echo "HyperOS GSI mirror — spring (HyperOS 2 / Android 15, Qualcomm)"
    echo "File: $GSI_FILE"
    echo "Source: MysticGSI (SourceForge) — Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip"
    echo "Device source: Redmi 15 5G / POCO M7 Plus 5G (Snapdragon 6s Gen 3)"
    echo "Size: $EXPECT_SIZE bytes"
    echo "MD5: $EXPECT_MD5"
    echo "SHA-256: $EXPECT_SHA256"
    echo ""
    echo "Parts (this Drive folder):"
    echo "$TOTAL" | tail -n +2 | while read -r nm sz md fid; do echo "  $nm  $sz bytes  md5=$md  file_id=$fid"; done
    echo ""
    echo "Rejoin after downloading all parts:"
    echo "  cat ${GSI_FILE}.part?? > ${GSI_FILE}"
    echo "  sha256sum ${GSI_FILE}   # expect $EXPECT_SHA256"
    echo "  md5sum ${GSI_FILE}      # expect $EXPECT_MD5"
    echo ""
    echo "Why parts: the Drive CLI cannot multipart-upload a single 3.1 GB file"
    echo "(Google 500); each 1 GiB part was uploaded separately and verified"
    echo "by size + md5Checksum. See gsi-drive-upload.log for the full record."
    echo "Mirror uploaded: $(TZ=Asia/Kolkata date '+%Y-%m-%d %H:%M %Z')"
} > "$README_PATH"
fw_log INFO drive "rejoin note written" path="$README_PATH"
if "$GWS_CLI" drive +upload "$README_PATH" --parent "$SUB_ID" --name "GSI-README.txt" 2>&1; then
    fw_log INFO drive "rejoin note uploaded" name="GSI-README.txt"
else
    fw_warn drive "rejoin note upload failed (parts above are unaffected)"
fi

# ------------------------------------------------------------------
# 4. log upload — the log itself goes to Drive with the GSI
# ------------------------------------------------------------------
fw_section "4. log upload"
fw_log INFO drive "uploading this log file to Drive" path="$FW_LOG_FILE"
if "$GWS_CLI" drive +upload "$FW_LOG_FILE" --parent "$SUB_ID" --name "gsi-drive-upload.log" 2>&1; then
    fw_log INFO drive "log uploaded" name="gsi-drive-upload.log"
else
    fw_warn drive "log upload failed (GSI parts above are unaffected)"
fi

fw_section "done"
fw_log INFO drive "GSI saved" drive_folder="backups/m51-hyperos/gsi" file="$GSI_FILE" bytes="$EXPECT_SIZE" md5="$EXPECT_MD5" sha256="$EXPECT_SHA256"
