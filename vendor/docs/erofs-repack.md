# EROFS repack + super sizing (ColorOS17)

Recipe from **Arnav3078/ColorOS17-SM7150** `scripts/port_coloros.sh`
+ `scripts/make_super.sh` (GPL-3.0), documented in
`research/09b-arnav-ports.md` §2. Credit: Arnav3078 + toraidl.
This doc is OUR write-up of the recipe for the HyperOS port.

## When this applies

**Only if the spring GSI is ever repacked as EROFS.** Spring is
ext4 (verified by magic bytes, docs/gsi-verification.md §3.1), so
the DSU trial and the first fastbootd flash do NOT need this.
Hyper371 proves the EROFS path works statically on this vendor
(EROFS system 1.43 GB + product 2.29 GB, `fsck.erofs` passed) —
this recipe is how to do it if the port ever goes that way
(e.g. to match a reference ROM's fstab, or to shrink the system).

## The recipe

1. **Repack with file-contexts** (SELinux labels must survive the
   repack, or the system boots with wrong labels):
   `mkfs.erofs --all-root --file-contexts=<plat_file_contexts> -z lz4hc,9 -C 65536`
   LZ4HC — NOT LZMA: this kernel's EROFS backport is LZ4-only
   (no `EROFS_FS_ZIP_LZMA` symbol; see docs/kernel-defconfig-plan.md).
2. **Unpack path:** `fsck.erofs --extract --xattrs` (xattrs preserved);
   loop-mount / `7z` are the fallbacks.
3. **Shrink the vendor first:** `resize2fs -M` on the vendor image
   ("frees ~450 MB empty padding").
4. **Super sizing (lpmake):** super 8,053,063,680 / group
   8,048,869,376 / metadata 65536 / 2 slots — the m51's actual
   super table (same as UN1CA's 8 GB dynamic partition table).
   **Hard-fail if the total exceeds the group** — never silently
   truncate an image to fit.
5. **Verify:** `vendor/scripts/verify_build.py` runs
   `fsck.erofs --xattrs --extract` on every .img and records the
   SHA-256 per image (Hyper371's verification discipline).

## Partition layout reference (Hyper371, docs/PARTITIONS.md)

system 1,435,795,456 B + product 2,287,689,728 B + vendor
809,484,288 B + odm 606,208 B = 4,533,575,680 B of the
8,048,869,376 B group — ~3.27 GiB free. No standalone `system_ext`
logical partition: Hyper371's `system_ext` lives at
`/system/system_ext` with `/system_ext -> /system/system_ext` and
`/system/product -> /product` symlinks. Use that layout if repacking.

## What would break

- LZMA-compressed EROFS: the kernel cannot mount it (no LZMA
  symbol). LZ4HC only.
- Repacking without `--file-contexts`: wrong SELinux labels, boot
  failures or denials that look like a policy problem but are a
  labelling problem.
- Forgetting the hard-fail on overflow: a truncated image flashes
  fine and bootloops.
- Importing ColorOS's `my_*` donor partitions: 8 extra partitions
  (`my_product`, `my_stock`, `my_heytap`, `my_carrier`,
  `my_region`, `my_bigball`, `my_manifest`, `my_engineering`)
  eat super space and need `nofail` fstab entries. The HyperOS
  port has no equivalent — import the sizing discipline, not the
  partitions.
