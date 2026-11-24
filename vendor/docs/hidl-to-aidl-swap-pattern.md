# HIDL→AIDL HAL-swap pattern (SpiderGirl-OS)

Pattern from **mehedihjoy0/SpiderGirl-OS** (fork of
SameerAlSahab/ProjectAstro / AstroROM, branch `ui-8.5`, MIT),
documented in `research/08c-mehedi-other-repos.md` §4. Credit:
AstroROM / SpiderGirl-OS. This doc is OUR write-up of the pattern
for the HyperOS port — not a copy of their scripts.

## The pattern

When the target system expects an AIDL HAL and the vendor only ships
the HIDL version, take the AIDL HAL **binary + its NDK platform
library from a newer Samsung device on the same SoC family** (SpiderGirl
uses the Galaxy S22 / r9q), install it into the vendor image, and
rewrite the VINTF manifest + compatibility matrix with sed so the
framework finds the new HAL instead of the old one.

SpiderGirl's working swaps (all on m51, builds green Oct 23–24 2026):
- **lights:** HIDL light service → AIDL `vendor.samsung.hardware.light-service`
  + `lib64/vendor.samsung.hardware.light-V1-ndk_platform.so` (r9q)
- **vibrator:** HIDL vibrator 2.2 → AIDL vibrator-service (r9q) + manifest sed
- **camera (snap):** AIDL snap HAL v3 from r9q, with manifest +
  compatibility-matrix sed rewrites, plus portrait-preview fix,
  `ueventd.rc` diff, midas + singletake blobs from the source firmware

## How to apply it here

1. Pick the smallest HAL first (vibrator — the Track H3 feasibility
   spike in port-plan.md §3). One swap at a time, never three at once.
2. Take the binary + NDK platform lib from the donor's vendor image.
   Record donor device, firmware version, and the files' SHA-256.
3. Rewrite the manifest + compatibility matrix with sed, exactly as
   SpiderGirl does — then run `vendor/scripts/vintf_precheck.py`
   BEFORE any device test, so a sed that deleted a HAL is caught on
   the desk, not on the phone.
4. Boot, check `lshal` / logcat for the new HAL, record what works.

## What would break

- **Do NOT apply the lights swap here.** Our lights fix is the
  source-built AIDL lights HAL (fork `kkisdevil/android_hardware_samsung`,
  no-op NOTIFICATIONS light, commit `e7968ab`). The binary r9q swap
  and the source-built HAL conflict — never apply both.
- **The RIL "fix" is not a HAL upgrade.** SpiderGirl's `ril/Fix-RIL.sh`
  is one sed: `1.4::IRadio` → `1.5::IRadio` in the manifest. If the
  framework then calls a 1.5 method the 1.4 HAL does not implement,
  calls fail at runtime. It looks fixed in the manifest and breaks
  on a call. Never use a version-string sed as a HAL upgrade.
- **Sed-based manifest surgery is brittle.** One upstream XML
  formatting change breaks the multi-line `N;N;N;…` patterns
  silently. Always run the VINTF precheck after the sed.
- **Donor binaries are black boxes.** A binary from r9q carries no
  source and no guarantee it works on the m51 vendor. The swap is
  proven only by a device test (logcat + `lshal`), never by the
  manifest looking right.
- **MIT vs our GPL-3.0:** borrowing the pattern is fine (MIT is
  compatible), but credit must be kept — this doc is that credit.

## Status

Pattern documented, unproven for HyperOS on m51. The first swap to
attempt is the vibrator (Track H3 spike). Camera AIDL wrapper is the
largest single item after RIL (port-plan.md §3 Track H3).
