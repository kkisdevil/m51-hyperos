# FCM bump recipe (SpiderGirl-OS)

Recipe from **mehedihjoy0/SpiderGirl-OS** `objectives/m51/fcm/FCM.sh`
(fork of SameerAlSahab/ProjectAstro / AstroROM, branch `ui-8.5`, MIT),
documented in `research/08c-mehedi-other-repos.md` §4. Credit:
AstroROM / SpiderGirl-OS. This doc is OUR write-up of the recipe for
the HyperOS port — not a copy of their script.

## The recipe

To move a vendor one FCM level up the support span (SpiderGirl:
device target-level 4 → 5):
1. Add `<kernel target-level="5"/>` to the device manifest.
2. Remove the configstore service + its policy (configstore is the
   HAL that pins the vendor to the old FCM level; without it the
   framework stops demanding the old level).
3. Run the VINTF precheck (`vendor/scripts/vintf_precheck.py`) after
   the change — a bump that deletes a HAL the framework still
   requires shows up as a mandatory FAIL.

## Open check — do NOT paper over this

**Vendor FCM target-level: 5 or 6?** Hyper371-M51
(`docs/VINTF.md`) says the M51 vendor manifest reports
`target-level="5"`. Our Phase 0 audit (`docs/tree-takeover.md`,
`trees/manifest.json`) says FCM target-level **6**. Both cannot be
the same manifest.

Possible causes: the device manifest vs the vendor manifest are
different files (different target-levels), or DXE3-era vs DXJ2-era
vendor. **Check before using this recipe:** read the actual
`/vendor/etc/vintf/manifest.xml` target-level from stock firmware
(DXE3 and DXJ2) and record which file each number came from. Until
that read is done, do not quote either number as settled, and do
not bump the FCM on the basis of either one.

Related open check: Hyper371 says "M51 exposes an AIDL vibrator
service"; our audit found the single AIDL entry to be
`vendor.samsung.hardware.media.converter`. Same manifest read
settles both.

## Why the recipe matters here

The governing problem for HyperOS is HIDL vs AIDL + the FCM support
span (not VNDK numbers). FCM 6 is inside Android 15's support span
(current + 6 previous), so HyperOS 2 is plausible without any bump.
The bump recipe is for the case where the framework refuses the
vendor as-is — it is a fallback, not a first step. For HyperOS 3
(Android 16) the recipe would need a frozen/optional FCM, which is
unproven on FCM 6 (port-plan.md §3 Track H3).

## What would break

- Bumping the target-level without removing configstore leaves the
  framework demanding the old level — the bump silently does nothing.
- Removing configstore while something still calls it breaks that
  caller at runtime. Check `lshal` + logcat for configstore callers
  first.
- A bump that nothing implements (like the RIL version sed) looks
  fixed in the manifest and breaks on a call.
