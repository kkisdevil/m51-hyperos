#!/usr/bin/env bash
# secilc_check.sh — offline SELinux combined-policy compile check (m51).
#
# Our own implementation of the method from Arnav3078/Hyper371-M51
# docs/SELINUX.md (credited in vendor/README.md): Hyper371 compiled
# its platform + product + system_ext policy together with the M51
# vendor policy offline with secilc, using the 30.0 mapping
# (plat_sepolicy_vers = 30.0), and it PASSED (return code 0, ~1.7 MiB
# policy). Our port plan's Phase 4 assumed enforcing was a from-scratch
# audit2allow project — this check reproduces Hyper371's result for
# OUR policy set first, before any enforcing attempt.
#
# What this does NOT prove: that the policy boots enforcing. Compiling
# != booting enforcing. Hyper371 recorded the same caveat (the M51
# ODM's precompiled policy hashes do not match the combined policy).
# A pass here moves the question from "unknown" to "compiles,
# untested on device".
#
# secilc comes from an AOSP build environment (out/host/linux-x86/bin/
# secilc) or the prebuilts. If it is not found, this script exits 2
# and says where to get it — a missing tool is not a policy failure.
#
# Usage:
#   bash secilc_check.sh --platform <dir> --vendor <dir>
#       [--product <dir>] [--system-ext <dir>]
#       [--mapping <dir>] [--out combined_policy]
#   Each <dir> holds .cil (and .cil.precompiled) policy files.
#   --mapping defaults to <platform>/mapping (the 30.0.cil +
#   30.0.compat.cil files Hyper371 ships).
#
# Exit codes: 0 compiled, 1 secilc failed (policy problem), 2 secilc
# missing / bad usage.

set -u

PLATFORM=""
VENDOR=""
PRODUCT=""
SYSTEM_EXT=""
MAPPING=""
OUT="combined_policy"

while [ $# -gt 0 ]; do
  case "$1" in
    --platform)   PLATFORM="$2"; shift 2 ;;
    --vendor)     VENDOR="$2"; shift 2 ;;
    --product)    PRODUCT="$2"; shift 2 ;;
    --system-ext) SYSTEM_EXT="$2"; shift 2 ;;
    --mapping)    MAPPING="$2"; shift 2 ;;
    --out)        OUT="$2"; shift 2 ;;
    --help|-h)
      sed -n '1,25p' "$0" | sed 's/^# //;s/^#//'
      exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$PLATFORM" ] && [ -n "$VENDOR" ] || {
  echo "error: --platform and --vendor are required" >&2
  exit 2
}
[ -z "$MAPPING" ] && MAPPING="$PLATFORM/mapping"

SECILC="$(command -v secilc || true)"
if [ -z "$SECILC" ]; then
  echo "secilc not found."
  echo "  It ships with an AOSP build environment:"
  echo "  out/host/linux-x86/bin/secilc (after building the platform),"
  echo "  or prebuilts/build-tools. A missing tool is not a policy"
  echo "  failure — install the build environment and re-run."
  exit 2
fi

POLICY_FILES=""
for dir in "$PLATFORM" "$PRODUCT" "$SYSTEM_EXT" "$VENDOR"; do
  [ -n "$dir" ] || continue
  [ -d "$dir" ] || { echo "error: no such directory: $dir" >&2; exit 2; }
  for f in "$dir"/*.cil; do
    [ -e "$f" ] || continue
    POLICY_FILES="$POLICY_FILES $f"
  done
done

MAPPING_ARGS=""
if [ -d "$MAPPING" ]; then
  for f in "$MAPPING"/*.cil; do
    [ -e "$f" ] || continue
    MAPPING_ARGS="$MAPPING_ARGS -M $f"
  done
fi

echo "secilc: $SECILC"
echo "policy files:$POLICY_FILES"
# shellcheck disable=SC2086
"$SECILC" $MAPPING_ARGS -o "$OUT" $POLICY_FILES
RC=$?
if [ "$RC" -eq 0 ]; then
  echo "secilc: COMPILED OK -> $OUT ($(stat -c%s "$OUT" 2>/dev/null || echo '?') bytes)"
  echo "  This proves the combined policy compiles. It does NOT prove"
  echo "  it boots enforcing — that needs a device test (Phase 4)."
else
  echo "secilc: FAILED (exit $RC) — fix the policy errors above before"
  echo "  any enforcing attempt."
fi
exit "$RC"
