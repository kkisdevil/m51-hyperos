# GSI verification — Mystic HyperOS builds for the m51 (Phase 1 prep)

Date: 2026-11-24. Verified **without downloading any image**: SourceForge
RSS listings + HTTP HEAD (Content-Length / Last-Modified / ETag only) +
public device/firmware pages. No GSI, firmware, or partial download was
made in this step.

Companion files: [reverse-engineering.md](reverse-engineering.md) §5
(GSI choice), [kernel-defconfig-plan.md](kernel-defconfig-plan.md) §3.3
(EROFS LZ4-only kernel constraint), `scripts/fetch-gsi.sh` (updated by
this verification — see §7), `m51-rom-builder` skill §8/§9.

## 0. Headline findings (read this first)

1. **The default build was wrong, and has been changed.** `fetch-gsi.sh`
   defaulted to `gold`, labelled "HyperOS 2 / Android 15". Gold is in
   fact **HyperOS 3.0.1.0 on Android 15, built from a MediaTek device**
   (Redmi Note 13 5G, Dimensity 6080). That contradicts the port plan's
   own rule — "Qualcomm-source GSI only, never a MediaTek-source one"
   (reverse-engineering.md §5) — because a MediaTek-source GSI drags in
   the MTK telephony/camera jars and forces the whole MTK RIL/ATMs shim
   chain (RE §2.3). The default is now **`spring`**: HyperOS 2.0.204.0,
   Android 15, built from the Redmi 15 5G / POCO M7 Plus 5G
   (**Qualcomm Snapdragon 6s Gen 3**). Gold stays available as an
   explicit `--build gold` option.
2. **All three Mystic builds exist at the URLs the script points to.**
   Exact sizes (HEAD Content-Length, confirmed by the ETag hex size),
   upload dates, and MD5s are in §1. The script's rounded sizes
   (3.6 / 3.1 / 4.0 GB) were correct within rounding.
3. **SourceForge DOES publish checksums — MD5, not SHA-256.** The
   script's "no publisher checksums exist" claim was wrong. MD5s are
   in the project RSS feed; `fetch-gsi.sh` now verifies MD5 on every
   download (§7). No SHA-256 is published anywhere for these files.
4. **Filesystem format is UNKNOWN from public metadata.** The
   MysticGSI tool defaults to ext4 and builds EROFS only with
   `--format lz4|lz4hc|lzma`, but no publisher note, Telegram post, or
   guide states which the published builds use. §3 records the evidence
   and the exact check that settles it (run right after download).
5. **Permissiver v5 has a verified direct download URL now**
   (sgsi137 project, §5). The DroidWin-guide link was real all along.
6. **No newer Mystic build exists for any of the three names** (§4).
   The stock firmware behind gold has moved on (OS3.0.11.0, Sep 2026),
   but Mystic has not published a newer gold GSI.

## 1. Verified GSI identity

SourceForge project `mystic-gsi-updates`, folder `/HyperOS/`.
Sizes are exact bytes from HTTP HEAD `Content-Length` (mirror response,
2026-11-24); dates are the files' `Last-Modified` / RSS `pubDate`
(identical); MD5s are from the SourceForge RSS feed for the folder.

| Build | File | HyperOS / Android | Source device (SoC) | Size (bytes) | Uploaded | MD5 (SourceForge RSS) |
|---|---|---|---|---|---|---|
| `spring` (**DEFAULT**) | `Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip` | **HyperOS 2.0.204.0 / Android 15** | Redmi 15 5G / POCO M7 Plus 5G — **Qualcomm Snapdragon 6s Gen 3** | **3,122,721,686** (~2.91 GiB / 3.12 GB) | 2025-12-06 16:58:15 UTC | `3e6337d1dd850ae2d0f7d067f8dd191c` |
| `gold` | `Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip` | **HyperOS 3.0.1.0 / Android 15** | Redmi Note 13 5G / POCO X6 Neo 5G — **MediaTek Dimensity 6080** | **3,554,104,547** (~3.31 GiB / 3.55 GB) | 2025-12-28 16:08:15 UTC | `edb87b9e088f0e1eaa5e8bf1c0ba6113` |
| `pudding` (experimental) | `Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip` | **HyperOS 3.0.50.2 / Android 16** | Xiaomi 17 — **Qualcomm Snapdragon 8 Elite Gen 5 (SM8850)** | **3,994,747,809** (~3.72 GiB / 3.99 GB) | 2026-01-22 14:24:15 UTC | `9eb03ec3f211365aecbaa346be9516b5` |

Download URLs (all HTTP 200, verified by HEAD 2026-11-24):

- spring: `https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip/download`
- gold: `https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/Hyperos-gold-15-OS3.0.1.0.VNQCNXM-AB-20251228-MysticGSI.zip/download`
- pudding: `https://sourceforge.net/projects/mystic-gsi-updates/files/HyperOS/Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip/download`

How each fact was established:

- **File / URL / date / MD5:** SourceForge RSS feed
  `https://sourceforge.net/projects/mystic-gsi-updates/rss?path=/HyperOS`
  (crawled 2026-11-24 05:23 UTC). Each item carries the path, download
  URL, `pubDate`, and an MD5 in its description. No SHA-256 appears
  anywhere in the feed, the file pages, or the project.
- **Exact sizes:** `curl -I` on each `/download` URL (headers only,
  zero bytes downloaded). The mirror `Content-Length` matches the
  SourceForge ETag's hex size field for all three files, and matches
  the script's rounded sizes within rounding.
- **HyperOS version vs Android version:** Xiaomi's version string is
  `OS<HyperOS>.<build>.<Android letter><device code><region>XM`, and
  the HyperOS number and the Android letter are independent — a phone
  can run HyperOS 3 on Android 15 (xiaomifirmware.com version decoder
  guide, verified 2026-11-24: `W` = Android 16, `V` = Android 15,
  `X` = Android 17; example given is exactly `OS3.0.5.0.VLLMIXM`,
  HyperOS 3 on Android 15). So `OS3.0.1.0.VNQCNXM` is HyperOS 3.0.1.0
  on Android 15, and `OS2.0.204.0.VOUMIXM` is HyperOS 2.0.204.0 on
  Android 15. The `-15-` / `-16-` in the Mystic filenames agrees in
  all three cases.
- **Source devices + SoCs:**
  - gold = Redmi Note 13 5G / POCO X6 Neo 5G, codename `gold`
    (hyperosupdate.com, xiaomirom.com — build `OS3.0.1.0.VNQCNXM`
    listed for gold/China); SoC **MediaTek Dimensity 6080**
    (mi.com official Redmi Note 13 5G specs; notebookcheck review).
  - spring = Redmi 15R 5G / REDMI 15 5G / POCO M7 Plus 5G, codename
    `spring` (xiaomirom.com — build `OS2.0.204.0.VOUCNXM` listed for
    spring/China; the Mystic file is the Global `VOUMIXM` of the same
    version); SoC **Qualcomm Snapdragon 6s Gen 3** (Wikipedia Redmi 15;
    multiple comparisons — `spring` = Redmi 15 5G / POCO M7 Plus).
  - pudding = Xiaomi 17, codename `pudding` (xiaomirom.com;
    phonedb.net "Xiaomi Pudding B"); SoC **Qualcomm Snapdragon 8 Elite
    Gen 5 / SM8850** (phonedb.net; unixnu.com devices table).

## 2. The gold correction — why the default changed

What the repo previously said (fetch-gsi.sh header, install.md §1,
port-plan.md §1, skill §8.2): gold is "HyperOS 2 / Android 15" and a
"Qualcomm-source" GSI. **Both halves were wrong:**

- Gold is **HyperOS 3.0.1.0** (not HyperOS 2) on Android 15. The
  "OS3" prefix is the HyperOS generation; the "V" is the Android 15
  base. Xiaomi shipped HyperOS 3 on Android 15 for this device (and
  for others — e.g. Redmi Note 12T Pro `OS3.0.1.0.VLHCNXM`, also
  Android 15). The RE doc's shorthand "HyperOS 2 = Android 15" is
  therefore imprecise: **Android 15 is the vendor-compat fact that
  matters** (HIDL tolerated, FCM 202404), and both HyperOS 2 and
  HyperOS 3 exist on it.
- Gold's source device is **MediaTek** (Dimensity 6080). A
  MediaTek-source GSI ships MTK telephony jars
  (`mediatek-telephony-base/common.jar`, `MtkTeleService`,
  `MtkRIL`) and MTK camera ATMs dependencies (RE §2.3) — exactly the
  components the port plan said to avoid, and the reason the A03
  project needed its T1.12–T1.14 hybrid-RIL + ATMs shims. Using gold
  as the default would have forced that whole shim chain on Phase 1
  for no benefit, on top of RIL already being the #1 hardest gap.

Spring is what Phase 1 was actually designed for: **HyperOS 2,
Android 15, Qualcomm source** — the same Android base (so the same
FCM/HIDL analysis applies unchanged), without the MTK jars. The only
cost is that spring's Mystic build is 22 days older than gold's
(2025-12-06 vs 2025-12-28) and its stock firmware is also older
(OS2.0.204.0 vs gold's OS3.0.1.0) — neither matters for a first boot,
and a newer HyperOS 2 build can be re-based later.

Gold is **not deleted**: it stays in the script as `--build gold` for
the HyperOS 3-on-Android-15 track (newer Xiaomi framework, same
Android 15 vendor contract), with its MediaTek-source status now
stated in the script so nobody picks it unknowingly. If gold is ever
used, the MTK RIL/ATMs shim chain (A03 T1.12–T1.14) must be planned
in from the start — it is not a surprise to discover at first boot.

## 3. Filesystem format — UNKNOWN (not determinable from public metadata)

**Verdict: unknown.** Neither EROFS nor ext4 (nor the EROFS
compressor) can be established for any of the three builds from
public metadata. This is stated explicitly because the kernel plan
hinges on it (kernel-defconfig-plan.md §3.3).

What was checked:

- **MysticGSI tool README** (github.com/MysticGSI/mysticgsi,
  2026-11-24): "By default, images are ext4. `--format` builds EROFS
  instead, typically 30-50% smaller: lz4hc saves less than lzma but
  reads faster on the device. The target device's kernel and fstab
  must support EROFS, and lzma needs `CONFIG_EROFS_FS_ZIP_LZMA`."
  The tool default is ext4 — but that says nothing about which flag
  the Mystic team passed when building the published zips.
- **MysticGSI Telegram channel** (t.me/s/mysticgsi, 2026-11-24): the
  public preview shows only the most recent posts (Pixel 17,
  OriginOS 7, open-source announcement). Those posts do list a "Raw
  Image Size" per build, but the Dec 2025 / Jan 2026 gold/spring/
  pudding announcement posts are buried hundreds of posts back and
  are not reachable from the preview.
- **DroidWin HyperOS 2 on Samsung guide**: describes flashing the GSI
  as `system.img` via fastbootd; says nothing about its filesystem.
- **Web search** (4 queries: MysticGSI EROFS/LZ4, gold raw image
  size, tool zip internals): no publisher statement of format for
  the published builds anywhere indexed.

Why zip size does not settle it: the gold zip is 3,554,104,547 bytes.
That is consistent with BOTH a ~7 GB ext4 raw image (free-space zeros
compress hard under zip deflate) and a ~3.5–4.5 GB EROFS lzma/lz4hc
image (already-compressed data barely shrinks further). No
discrimination is possible from the size alone, and no other public
number (raw image size, partition table) is published for these
builds.

### What it means for the kernel (read before downloading)

- **If ext4:** nothing new is needed. The m51 fstab already mounts
  system ext4 (tree-takeover.md §5); the stock kernel mounts it too,
  so even the DSU trial on the stock kernel works.
- **If EROFS + LZ4/LZ4HC:** the merged defconfig already covers it
  (`EROFS_FS` + `ZIP` + `XATTR` + `POSIX_ACL` + `SECURITY` in
  `kernel/m51_defconfig`, kernel-defconfig-plan.md §4), **but** the
  m51 fstab has **no EROFS entry** (tree-takeover.md §5) — one must be
  added, and the custom kernel must be built/flashed before the DSU
  trial, because the stock 4.14.190 kernel is ext4-era and its EROFS
  support is unproven (check on-device first:
  `zcat /proc/config.gz | grep EROFS` — expected absent).
- **If EROFS + LZMA:** the kernel **cannot mount it**. The crDroid
  EROFS backport has no `EROFS_FS_ZIP_LZMA` symbol
  (kernel-defconfig-plan.md §3.3). That would need either a different
  GSI (ext4 or LZ4) or the LZMA backport as a separate work item —
  do not start the DSU trial until this is resolved.

### What settles it (exact next step, after download — NOT done here)

After `scripts/fetch-gsi.sh` downloads the image (spring default):

```sh
unzip -l downloads/Hyperos-spring-15-OS2.0.204.0.VOUMIXM-AB-20251206-MysticGSI.zip
# note the uncompressed size of system.img: ~7 GB points to ext4,
# ~3.5-5 GB points to EROFS
unzip -p downloads/<file>.zip system.img | dd bs=1 skip=1024 count=16 2>/dev/null | xxd
# EROFS superblock magic at offset 1024: e2 e1 f5 e0 (0xE0F5E1E2)
# ext4 superblock magic at offset 1080: 53 ef (0x53EF)
file downloads/system.img          # or: dump.erofs / debugfs -R stats
```

Cheaper alternative that avoids touching the image at all: an HTTP
Range request for the zip's trailing central directory gives each
entry's uncompressed size — but that is still a partial download of
the archive, so it belongs to the download step, not this
verification step. **Do not** treat the format as known until one of
the checks above has actually run.

## 4. Newer-build check

Checked against the full SourceForge `/HyperOS/` RSS listing
(2026-11-24 05:23 UTC, newest first):

- **No newer Mystic `gold` build:** the only gold file in the folder
  is `OS3.0.1.0` (2025-12-28). The *stock* gold firmware has moved
  on — China builds `OS3.0.5.0` (2026-01-08), `OS3.0.7.0`
  (2026-02-06), `OS3.0.9.0` (2026-05-14), `OS3.0.10.0`
  (2026-07-15), `OS3.0.11.0` (2026-09-24), all `VNQCNXM`,
  Android 15 — but Mystic has published no GSI from any of them.
  A re-base would need MysticGSI to rebuild (or a local
  `mysticgsi` build from the newer firmware), not a new download.
- **No newer Mystic `spring` build:** the only spring file is
  `OS2.0.204.0` (2025-12-06). Stock spring firmware moved on too
  (India `OS2.0.208.0`, 2026-02-04; then HyperOS 3 / Android 16
  `OS3.0.303.0`, 2026-07-23) — again, no newer Mystic spring GSI.
- **No newer Mystic `pudding` build:** `OS3.0.50.2` (2026-01-22) is
  the newest file in the whole folder and the only pudding file.
  Other HyperOS 3 builds in the folder are older: nezha
  `OS3.0.5.0` (2026-01-18), dijun `OS3.0.9.0` (2026-01-14), fuxi
  `OS3.0.2.0` (2025-12-10), goya `OS3.0.5.0` (2025-12-07), dada
  `OS3.0.5.0` (2025-12-05), duchamp `OS3.0.0.4` (2025-12-05).
- **Other HyperOS 2 (Android 15) Mystic builds in the folder** (same
  era, different source devices — not gold/spring/pudding, listed for
  completeness): creek `OS2.0.210.0` (2025-11-02), warm
  `OS2.0.202.0` (2025-11-02), fuxi `OS2.0.207.0` (2025-09-14), dada
  `OS2.0.215.0` (2025-09-02), dali `OS2.0.218.0` (2025-08-24).
  Of these, **fuxi** (Xiaomi 13, Snapdragon 8 Gen 2) and **dada**
  (Xiaomi 15, Snapdragon 8 Elite) are also Qualcomm-source HyperOS 2
  builds — fallback candidates if spring ever goes stale. Creek
  (Redmi 15 4G, Snapdragon 685) is Qualcomm too but older.
- **HyperOS 4 exists for pudding in stock firmware** (`OS4.0.6.0.
  XPCCNXM`, China, 2026-10-26; `X` = Android 17) but **no Mystic
  HyperOS 4 GSI has been published**. Out of scope for this port.

## 5. Permissiver v5 — verified direct download URL: YES

The DroidWin guide's "Permissiver v5" link is real and live. It
points to the **sgsi137** SourceForge project (not Wahyu6070's
similarly-named file — that is a different "Selinux Permissiver.zip";
use the sgsi137 one, which is what the guide links):

- **URL:**
  `https://sourceforge.net/projects/sgsi137/files/Permissiver%20v5.zip/download`
- **Verified:** HTTP 200 at the SourceForge mirror (HEAD, 2026-11-24).
- **Size:** **1,251,096 bytes** (~1.19 MiB), `Content-Length`.
- **Uploaded:** Sun, 02 Jan 2022 07:57:06 GMT (`Last-Modified`, matches
  the RSS `pubDate`).
- **MD5 (SourceForge RSS):** `73f68347929e484351d2ca1f72360381`
- **ETag:** `"61d15ad2-131718"` (hex size `0x131718` = 1,251,096 ✓).

Context: sgsi137 is a small Jan–Feb 2022 GSI helper collection
(siblings in the same project: `Vbmeta_Patch.zip`,
`Vendor_Boot_Patch.zip`, `Patch3.zip`, `README.txt`, `Guide.txt`).
The file is old (2022) but it is the canonical Permissiver v5 every
Samsung GSI guide links — there is no newer version; v5 is the last.
It is a TWRP-flashable zip that patches the boot image to permissive
(`androidboot.selinux=permissive`); for this port the same effect is
produced by the custom permissive boot image (kernel-defconfig-plan.md
§5), so Permissiver v5 is the fallback / DSU-trial path, not the
primary one. Verify its MD5 after download — a 2022 file on a
mirror is exactly the kind of thing worth hashing before flashing.

## 6. Go / no-go for the Phase 1 first boot (DSU trial)

**CONDITIONAL GO — for `spring` (the new default), with two gates
that must clear before the DSU trial, in this order:**

1. **Download + verify.** `bash scripts/fetch-gsi.sh` (spring
   default) — the script now checks size against the exact byte
   count and MD5 against the publisher hash in §1, then the archive
   integrity test. A download that fails any of those is not used.
2. **Determine the format** (§3 settling step) and act on it:
   - ext4 → proceed to the DSU trial on the stock kernel.
   - EROFS LZ4 → add the fstab EROFS entry and build/flash the
     custom kernel (`kernel/m51_defconfig` already enables EROFS
     LZ4) before the DSU trial.
   - EROFS LZMA → STOP: pick a different GSI or schedule the LZMA
     backport work item. Do not start the DSU trial.
3. **DSU trial** per [dsu-trial.md](dsu-trial.md), then first-failure
   triage per the port plan. Gold is not the first-boot image: it is
   the HyperOS 3-on-15 / MediaTek track, to be tried only after
   spring boots (or if the MTK shim chain is deliberately chosen).

**No-go items (unchanged):** the DSU trial still needs the physical
m51 with an unlocked bootloader + a stock-firmware backup + Odin
restore path (skill §9); nothing in this verification substitutes
for that. The format question (§3) is the only new gate this
verification adds.

## 7. What changed in `scripts/fetch-gsi.sh` (this verification)

- **Default `gold` → `spring`.** Reason in §2. The gold/spring/
  pudding structure is unchanged — all three builds are still listed
  and selectable with `--build`.
- **Corrected labels everywhere** (header comment, `--list`, usage):
  gold is HyperOS **3.0.1.0** / Android 15, **MediaTek** source
  (Redmi Note 13 5G); spring is HyperOS **2.0.204.0** / Android 15,
  **Qualcomm** source (Redmi 15 5G); pudding is HyperOS **3.0.50.2** /
  Android 16, **Qualcomm** source (Xiaomi 17). Source devices and
  SoCs are now recorded in the script comments.
- **Exact sizes:** `EXPECTED_BYTES` is now the exact HEAD
  Content-Length per build (gold 3554104547, spring 3122721686,
  pudding 3994747809), still checked with the ±10% tolerance.
- **MD5 verification added:** `EXPECTED_MD5` per build (the
  publisher MD5s from §1); the script now runs `md5sum` after the
  size check and fails on mismatch. The old "no publisher checksums
  exist" claim is removed — SourceForge publishes MD5 (RSS); no
  SHA-256 exists, so the script still records SHA-256 locally for
  future reference and `--sha256` still compares against a
  user-supplied hash.
- **Nothing else changed:** same URLs, same file names, same
  `--file` / `--url` / `--extract` / `--dry-run` behaviour.

## 8. Stale references this step did NOT fix (follow-ups)

> **Resolved 2026-11-24** — the follow-up sweep is done: `docs/install.md`
> §1 + unzip example, `docs/port-plan.md` §1 + target table + Phase 1,
> `README.md`, skill §8.2, and `docs/reverse-engineering.md` §§2.1–2.2/§5
> now name `spring` as the HyperOS 2 / Qualcomm default and label `gold`
> correctly (HyperOS 3.0.1.0 / Android 15, MediaTek). The
> `docs/kernel-defconfig-plan.md` "Mystic gold" mentions and the
> `docs/faq.md` "HyperOS 3 is Android 16" shorthand were fixed in the
> same sweep. The list below is kept as the record of what was stale
> before the sweep.

Per the task scope (script + this doc + skill log only), these still
name gold as the HyperOS 2 / Qualcomm default and need a follow-up
edit in a later step — do not treat them as current:

- `docs/install.md` §1 table ("gold (default) … 15 / HyperOS 2")
  and its `unzip Hyperos-gold-...` example.
- `docs/port-plan.md` §1 ("Qualcomm-source Mystic HyperOS 2 GSI
  (gold, Android 15)") and its target table ("Mystic `gold` build …
  `gold`, OS2.x").
- `README.md` ("HyperOS 2 by default", "Qualcomm-source HyperOS 2
  GSI as the base").
- `m51-rom-builder` skill §8.2 ("Qualcomm-source Mystic HyperOS 2
  GSI (gold, Android 15)") — the correction is recorded in the
  skill's learnings log instead (see skill §13); the §8.2 text still
  needs the follow-up edit.
- `docs/reverse-engineering.md` §2.2/§5 shorthand "HyperOS 2 =
  Android 15" — now known to be imprecise (HyperOS 3 also ships on
  Android 15); the vendor-compat conclusions are unaffected because
  they rest on the Android base, not the HyperOS marketing version.
- `docs/dsu-trial.md` says "HyperOS 2 default" — still true under
  the new default (spring IS HyperOS 2); no change needed there.

## 9. Sources

- SourceForge RSS, Mystic HyperOS folder (file list, dates, MD5s):
  `https://sourceforge.net/projects/mystic-gsi-updates/rss?path=/HyperOS`
  (crawled 2026-11-24 05:23 UTC).
- SourceForge RSS, sgsi137 project (Permissiver v5 date + MD5):
  `https://sourceforge.net/projects/sgsi137/rss?path=/`
  (crawled 2026-11-24 05:28 UTC).
- HTTP HEAD (Content-Length / Last-Modified / ETag, zero bytes
  downloaded) on the three GSI `/download` URLs and the Permissiver
  v5 `/download` URL (2026-11-24 05:24–05:25 UTC).
- MysticGSI tool README (default ext4, `--format` for EROFS):
  `https://github.com/MysticGSI/mysticgsi` (2026-11-24).
- MysticGSI Telegram channel (recent posts only; gold/spring/pudding
  announcement posts not reachable from the preview):
  `https://t.me/s/mysticgsi` (2026-11-24).
- Xiaomi version-string decoder (HyperOS number vs Android letter
  are independent; W=16, V=15, X=17; PC=pudding):
  `https://xiaomifirmware.com/guides-and-tips/xiaomi-rom-region-codes-mixm-euxm-change-region/`
  and `https://xiaomifirmware.com/xiaomi-firmware-version-decoder/`.
- gold = Redmi Note 13 5G / POCO X6 Neo 5G, Dimensity 6080:
  `https://hyperosupdate.com/firmware/gold_global`,
  `https://xiaomirom.com/en/rom/redmi-note-13-5g-13r-pro-gold-china-fastboot-recovery-rom/`,
  `https://www.mi.com/in/product/redmi-note-13-5g/`.
- spring = Redmi 15 5G / POCO M7 Plus 5G, Snapdragon 6s Gen 3:
  `https://xiaomirom.com/en/rom/redmi-15r-5g-15-5g-poco-m7-plus-5g-spring-china-fastboot-recovery-rom/`,
  `https://en.wikipedia.org/wiki/Redmi_15`.
- pudding = Xiaomi 17, Snapdragon 8 Elite Gen 5 (SM8850):
  `https://xiaomirom.com/en/rom/xiaomi-17-pudding-global-fastboot-recovery-rom/`,
  `https://phonedb.net/index.php?m=Device&id=25198&c=xiaomi_mi_17_5g_standard_edition_global_dual_sim_td-lte_512gb_25113pn0eg__xiaomi_pudding_b&d=detailed_specs`,
  `https://unixnu.com/devices/`.
- DroidWin HyperOS 2 on Samsung guide (Permissiver v5 link target,
  GSI flash steps, bug list):
  `https://droidwin.com/how-to-flash-hyperos-2-android-15-gsi-on-samsung/`.
- Prior docs: `docs/reverse-engineering.md` §2.2/§2.3/§5,
  `docs/kernel-defconfig-plan.md` §3.3, `docs/tree-takeover.md` §5,
  `docs/port-plan.md` §1/§3, `docs/dsu-trial.md`.
