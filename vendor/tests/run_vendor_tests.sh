#!/usr/bin/env bash
# run_vendor_tests.sh — run the vendor tools against synthetic fixtures.
#
# Builds the fixtures (vendor/tests/make_fixtures.py), runs every
# vendor script against them, and asserts the expected behaviour.
# No real firmware, GSI, or device is needed. Exit 0 when all checks
# pass, 1 otherwise.
#
# Usage: bash vendor/tests/run_vendor_tests.sh

set -u
cd "$(dirname "$0")/.."   # vendor/
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 tests/make_fixtures.py "$TMP/fixtures" >/dev/null || {
  echo "fixture build failed"; exit 1
}
F="$TMP/fixtures"

echo "== patch_boot.py =="
python3 scripts/patch_boot.py "$F/boot-v2.img" "$TMP/patched.img" >/dev/null 2>&1
RC=$?
[ "$RC" -eq 0 ] && ok "patch_boot exits 0" || bad "patch_boot exits $RC"
python3 scripts/patch_boot.py "$F/boot-v2.img" "$TMP/patched.img" --dry-run \
  | grep -q "androidboot.selinux=permissive" \
  && ok "cmdline gains permissive" || bad "cmdline gains permissive"
python3 - <<EOF
import gzip, struct, sys
sys.path.insert(0, "scripts")
from patch_boot import parse_header, segments, _cpio_read
data = open("$TMP/patched.img", "rb").read()
hdr = parse_header(data)
assert hdr["version"] == 2, hdr["version"]
segs = dict((n, (o, s)) for n, o, s in segments(hdr))
off, size = segs["ramdisk"]
entries = _cpio_read(gzip.decompress(data[off:off+size]))
fstab = dict((n, b) for n, m, b in entries)["fstab.sm7150"].decode()
assert "fileencryption=ice" not in fstab, "ICE still present"
assert "encryptable" in fstab, "encryptable missing"
assert ",avb" not in fstab and "avb_keys" not in fstab, "AVB still present"
assert hdr["extra_cmdline"].find("androidboot.selinux=permissive") >= 0, "no permissive in extra_cmdline"
print("  ok: fstab rewritten (ICE->encryptable, AVB stripped); permissive in extra_cmdline")
EOF
[ "$?" -eq 0 ] || FAIL=$((FAIL+1))

echo "== patch_fstab.py =="
python3 scripts/patch_fstab.py "$F/fstab.qcom" "$TMP/fstab.out" >/dev/null 2>&1
grep -q "encryptable" "$TMP/fstab.out" \
  && ok "fstab ICE->encryptable" || bad "fstab ICE->encryptable"
grep -q "avb" "$TMP/fstab.out" \
  && bad "fstab AVB stripped" || ok "fstab AVB stripped"
python3 scripts/patch_fstab.py "$F/fstab.qcom" "$TMP/fstab2.out" --erofs >/dev/null 2>&1
grep -q "erofs" "$TMP/fstab2.out" \
  && ok "fstab --erofs adds EROFS entries" || bad "fstab --erofs adds EROFS entries"

echo "== vintf_precheck.py =="
OUT="$(python3 scripts/vintf_precheck.py --matrix "$F/matrix.5.xml" \
  --manifest "$F/manifest.xml" 2>&1)"
echo "$OUT" | grep -q "mandatory FAIL: 1" \
  && ok "precheck counts 1 mandatory FAIL (missing foo)" \
  || bad "precheck counts 1 mandatory FAIL (got: $(echo "$OUT" | grep 'mandatory FAIL'))"
echo "$OUT" | grep -q "UNCHECKED: 1" \
  && ok "precheck counts 1 UNCHECKED (unparseable version)" \
  || bad "precheck counts 1 UNCHECKED"
python3 scripts/vintf_precheck.py --matrix "$F/matrix.5.xml" \
  --manifest "$F/manifest.xml" >/dev/null 2>&1
[ "$?" -eq 1 ] && ok "precheck exits 1 on mandatory FAIL" \
  || bad "precheck exits 1 on mandatory FAIL"

echo "== auto_gen_facts.py =="
python3 scripts/auto_gen_facts.py "$F/stock" > "$TMP/facts.json" 2>&1
RC=$?
[ "$RC" -eq 0 ] && ok "auto_gen_facts exits 0" || bad "auto_gen_facts exits $RC"
grep -q '"model": "SM-M515F"' "$TMP/facts.json" \
  && ok "model read from build.prop" || bad "model read from build.prop"
grep -q '"fcm_target_level": "6"' "$TMP/facts.json" \
  && ok "FCM target-level read from manifest" \
  || bad "FCM target-level read from manifest"
grep -q '"siop_policy": "siop_m51_sm7150.xml"' "$TMP/facts.json" \
  && ok "SIOP policy filename found" || bad "SIOP policy filename found"
grep -q '"HFR_DEFAULT_REFRESH_RATE": "60"' "$TMP/facts.json" \
  && ok "HFR value read from floating feature" \
  || bad "HFR value read from floating feature"

echo "== backlight_triage.sh =="
bash scripts/backlight_triage.sh --sysfs "$F/sysfs" > "$TMP/triage.txt" 2>&1
[ "$?" -eq 1 ] && ok "triage exits 1 on dark panel" \
  || bad "triage exits 1 on dark panel"
grep -q "panel0-backlight" "$TMP/triage.txt" \
  && ok "triage finds panel0-backlight node" || bad "triage finds panel node"
grep -q "actual_brightness is 0" "$TMP/triage.txt" \
  && ok "triage diagnoses lying brightness" || bad "triage diagnoses lying brightness"
bash scripts/backlight_triage.sh --sysfs "$F/sysfs" --fix >/dev/null 2>&1
[ "$(cat "$F/sysfs/class/backlight/panel0-backlight/bl_power")" = "0" ] \
  && ok "--fix unblanks bl_power" || bad "--fix unblanks bl_power"
[ "$(cat "$F/sysfs/class/backlight/panel0-backlight/brightness")" = "5721" ] \
  && ok "--fix sets early-unblank 5721 (13510*180/425)" \
  || bad "--fix sets early-unblank (got $(cat "$F/sysfs/class/backlight/panel0-backlight/brightness"))"

echo "== verify_build.py =="
python3 scripts/verify_build.py "$F/build-out" --expected "$F/hashes.json" \
  --report "$TMP/VERIFICATION.md" >/dev/null 2>&1
[ "$?" -eq 0 ] && ok "verify_build exits 0 with matching hashes" \
  || bad "verify_build exits 0 with matching hashes"
grep -q "system.img" "$TMP/VERIFICATION.md" \
  && ok "VERIFICATION.md lists files" || bad "VERIFICATION.md lists files"
python3 - <<EOF
import json
h = json.load(open("$F/hashes.json"))
h["system.img"] = "0" * 64
json.dump(h, open("$TMP/bad-hashes.json", "w"))
EOF
python3 scripts/verify_build.py "$F/build-out" --expected "$TMP/bad-hashes.json" \
  >/dev/null 2>&1
[ "$?" -eq 1 ] && ok "verify_build exits 1 on hash mismatch" \
  || bad "verify_build exits 1 on hash mismatch"

echo "== secilc_check.sh =="
bash scripts/secilc_check.sh --platform /nonexistent --vendor /nonexistent \
  >/dev/null 2>&1
[ "$?" -eq 2 ] && ok "secilc_check exits 2 when tool/dirs missing" \
  || bad "secilc_check exits 2 when tool/dirs missing"

echo
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
