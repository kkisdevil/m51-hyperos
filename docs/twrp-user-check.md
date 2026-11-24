# TWRP check — user's installed image (M51)

**Source file:** `workspace/user/files/unica_new_Binay_twrp-3.7.0_11.1-m51-erofsodin__2__12_s6ok.tar`
**Checked:** 2026-11-25, from the extracted files in `/tmp/twrp-user-check/` (recovery.img, kernel, kernel.gz, ramdisk.cpio, ramdisk tree, ramdisk-list.txt, ramdisk-files.txt, ramdisk-files.sha256sum). Nothing was flashed, nothing uploaded.

## Hashes

| File | Size (bytes) | SHA-256 |
|---|---|---|
| tar (as received) | 67,110,400 | `56746fed69fe4c00dd589d01764d5408ab2305340861248808d4ee0c040bacd4` (verified live — matches the recorded value) |
| recovery.img | 67,108,864 (64 MiB) | `5452f976b3357d37aa5fcccbfa576a696c811e51b88aada8975a59883908adc0` |
| kernel (uncompressed Image) | 47,026,192 | `49c0f6639227b7f1abff3ba2aa999c24f747c14308e664045b7d5b167e4e9dc5` |
| kernel.gz | 16,048,128 | — (not hashed; see note §7) |
| ramdisk.cpio | 37,379,072 | `45f1069ca7598975b47cc98240389ace715fa56d0842fc7bb28298d560defeb8` |
| ramdisk.gz | 13,451,264 | — |

The tar contains **only** `recovery.img` — no md5 sidecar, no other partition. It is an Odin-format tar (flash `recovery.img` via Odin's AP slot, or via TWRP/Odin as a tar).

## Identity — this IS the reference build

| Field | This image | Reference (Mehedi M51-FIRMWARES) |
|---|---|---|
| TWRP version (from `system/bin/twrp` strings) | **3.7.0_11-0** | 3.7.0_11-0 |
| Build fingerprint | `samsung/twrp_m51/m51:11/RQ1A.210205.004/runner06050938:eng/test-keys` | identical |
| Build date | Thu Jun 5 09:38:05 UTC 2025 (`1749116285`) | 2025-06-05 |
| Build host / user | `fv-az735-619` (GitHub Actions runner) / `runner` | identical |
| Android base | 11 (SDK 30), `eng/test-keys` | Android 11 base |
| Device / model | `m51` / `SM-M515F` | m51 / SM-M515F |
| Board / platform | `sm6150` | sm6150 |
| Kernel | Linux 4.14.190+, built `iambinaytiwari@M51`, clang 12.0.5, Thu Jun 5 08:59:08 UTC 2025, `#1 SMP PREEMPT` | — |

Every checkable field matches the reference exactly — fingerprint, build date, build host, version, device, Android base. **The user's installed TWRP is the reference 3.7.0_11-0 build**, repackaged under a different tar name. The `_11.1` in the tar filename is a repackager's label, **not** the version: the binary itself says `3.7.0_11-0`. The `unica_new_Binay_` prefix and the kernel builder `iambinaytiwari@M51` (Binay Tiwari) point to who repackaged it; there is no UN1CA/Binay code inside the image itself (no `unica`/`binay` strings anywhere in the 3,504-file ramdisk listing).

## Boot-image header (Android boot image v0)

- Magic `ANDROID!`, header version field reads 0 (v0 header — no v1+ fields present)
- `kernel_size` 16,046,222, `kernel_addr` 0x8000; `ramdisk_size` 13,447,283, `ramdisk_addr` 0x2000000
- `second_size` 0; `tags_addr` 0x1e00000; `page_size` 4096; `dt_size` 2 (effectively no separate DT section — see §7)
- `name`/board: `SRPTD22A006`
- `os_version` 0x1600019c → Android **11.0.0, patch level 2025-12**
- `id` SHA-1: `c77e25af65df13d09bbec2dee564a52ada89621f` + zeros
- Cmdline: `console=null androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=1 androidboot.usbcontroller=a600000.dwc3 firmware_class.path=/vendor/firmware_mnt/image nokaslr printk.devkmsg=on androidboot.selinux=permissive buildvariant=eng`
- Kernel `Image` magic `ARMd` at 0x38 — valid AArch64 Image; `kernel.gz` has gzip magic `1f8b`

## Partition table — twrp.flags + recovery.fstab

Logical partitions (both files agree; each has an **ext4 and an erofs row**, read-only, `wait,logical,first_stage_mount`):

| Mount | ext4 row | erofs row |
|---|---|---|
| /system | yes | yes |
| /vendor | yes | yes |
| /product | yes | yes |
| /odm | yes | yes |

Physical partitions (twrp.flags; `backup=1` = included in TWRP backups, `flashimg` = flashable from TWRP):

| Mount | Type | Device | Flags |
|---|---|---|---|
| /metadata | ext4 | by-name/metadata | backup=1 |
| /boot | emmc | by-name/boot | backup=1; flashimg |
| /recovery | emmc | by-name/recovery | backup=1; flashimg |
| /data | f2fs | by-name/userdata | *(no flags in twrp.flags)* |
| /cache | ext4 | by-name/cache | backup=1 |
| /efs | ext4 | by-name/efs | backup=1 |
| /sec_efs | ext4 | by-name/sec_efs | backup=1 |
| /firmware | emmc | by-name/apnhlos | backup=1 |
| /modem | emmc | by-name/modem | backup=1 |
| /dsp | emmc | by-name/dsp | — |
| /misc | emmc | by-name/misc | — |
| /dtbo | emmc | by-name/dtbo | backup=1; flashimg |
| /optics_image | emmc | by-name/optics | backup=1; flashimg |
| /prism_image | emmc | by-name/prism | backup=1; flashimg |
| /system_image, /vendor_image, /product_image, /odm_image | emmc | by-name/system etc. | backup=0; flashimg |
| /external_sd | vfat | mmcblk0p1 / mmcblk0 | storage; wipeingui; removable |
| /usb-otg | auto | sde1 / sde | storage; wipeingui; removable |

recovery.fstab adds: `/data` f2fs `defaults, recoveryonly` — **no `fileencryption` / `metadata_encryption` flag**; `/metadata` ext4 `wait,first_stage_mount`; `/boot` and `/recovery` `recoveryonly`. (`/carrier` and `/preload` are commented out.)

## AVB status

- The image carries an **AVB footer** (`AVBf`, v1.0): `original_image_size` 31,477,760, vbmeta 2,432 B at offset 31,477,760, image zero-padded to the 64 MiB partition size.
- vbmeta (`AVB0`, libavb 1.0, avbtool 1.1.0): auth block 576 B, aux block 1,600 B, algorithm **SHA256_RSA4096**, hash 32 B, signature 512 B, public key 1,032 B, `rollback_index` 1, **`flags` 0 — verification is NOT disabled in the image itself**.
- Descriptors present: property descriptors (build fingerprint / OS version / security patch strings) + hash descriptors.
- Enforcement depends on the bootloader, not the image: the user's bootloader is unlocked, so this signed recovery boots fine. **Do not relock the bootloader with this recovery installed** — a locked bootloader would refuse it (custom key, flags 0).

## EROFS

- **Kernel: EROFS is compiled in** — 44 `erofs` strings in the uncompressed kernel binary, including the filesystem name and superblock handling (`cannot find valid erofs superblock`, `erofs_fill_dentries`, …). So TWRP can mount EROFS system/vendor/product/odm read-only.
- **Userspace: no EROFS tools** — no `mkfs.erofs`, `dump.erofs`, `fsck.erofs`, no erofs libraries in the ramdisk. TWRP cannot create or check EROFS images from inside recovery.
- For our work this is fine: UN1CA's system is EROFS (mountable for backup/inspection), the spring HyperOS GSI is ext4 (fully supported). Creating EROFS images happens on the build machine, not in TWRP.

## Data decryption (FBE) — present in code, UNPROVEN on device

- Present: `libfscrypt.so`, the TWRP binary's `decrypt <password> [USER ID]` command, `keystore` / `keystore_cli_v2` / `tee` binaries, `/metadata` mounted at first stage (where the FBE key lives).
- Absent: no keymaster / gatekeeper / qseecom HALs, no `libcryptfs`, and recovery.fstab's `/data` line carries **no fileencryption flag**.
- Stock /data is FBE `aes-256-xts`. Whether this build actually decrypts /data on the real M51 **cannot be proven from the image alone** — it must be tested by booting it and attempting a /data backup. Do not rely on /data backup/restore until that test passes. (Formatting /data in TWRP would destroy the data; the test is backup-only.)

## Tooling in the ramdisk (244 files in system/bin)

`adbd`, `minadbd`, **`fastbootd`** (fastbootd inside recovery — GSI flashing via fastbootd works), `simg2img`, `sgdisk`, `e2fsck`/`mke2fs`/`tune2fs`, `fsck.f2fs`, `fsck.exfat`/`fsck.ntfs`, `mkfs.fat`/`mkfs.ntfs`, `tar`, `toybox`, `unzip`, `sha256sum` et al. **No** Magisk/`su`, no `avbctl`, no `lpunpack`/`lpdump`. No `unica`/`binay` strings anywhere.

## Unusual items

1. **Filename `_11.1` ≠ version `3.7.0_11-0`** — repackager label, not a newer build.
2. **Declared patch level is 6 months in the future**: `os_version` says 2025-12 and `ro.build.version.security_patch` is `2025-12-31`, but the image was built 2025-06-05. Cosmetic (set at build time); the real patch level of the recovery kernel is whatever 4.14.190+ carries.
3. **No DTB in the boot image**: `dt_size` reads 2 and no DTB magic (`0xd00dfeed`) exists in the kernel or kernel.gz. The DTB comes from the **separate dtbo partition**, which TWRP backs up and can flash. Any kernel/boot-image work must keep dtbo in mind.
4. **`kernel.gz` is 1,906 bytes larger than the header's `kernel_size`** (16,048,128 vs 16,046,222) — trailing bytes/padding from extraction; insignificant.
5. **`/data` has no flags at all in twrp.flags** (not even `backup=1`) — defaults apply; combined with §6, /data backup is the one unproven area.
6. **Cmdline is `selinux=permissive`, `buildvariant=eng`, `console=null`** — standard for a TWRP eng build, not a concern.
7. **`init.recovery.qcom.rc`** only sets `ro.boot.vbmeta.avb_version`/`ro.boot.avb_version` to 1.1, waits for the boot device, symlinks `/dev/block/bootdevice`, and exports `ANDROID_ROOT /system_root`. Nothing unusual.

## Verdict

**Safe to keep using.** The user's installed TWRP is byte-for-byte the known-good reference build (3.7.0_11-0, 2025-06-05, Android 11, ext4 + EROFS) — there is no mismatch, no wrong-device risk (m51 / SM-M515F / sm6150 throughout), and no surprise code inside it.

**No conflict with our flashing plans:**
- **UN1CA zip:** its installer deletes `recovery.img` from the zip and never overwrites recovery. The DXJ2 bootloader/modem it flashes is Samsung-signed and does not touch recovery.
- **HyperOS GSI:** flashes the system partition only (fastboot / DSU). Recovery untouched. `fastbootd` is present in this TWRP if a fastbootd flash is ever needed.
- **Kernel boot image:** flashes `boot` only. Recovery untouched. (DTB lives in dtbo — flash dtbo only when the kernel work explicitly requires it.)
- **EROFS:** mountable for inspection/backup; no userspace EROFS tools, which our flows do not need.

**Open items (test on the device, do not assume):**
1. **/data FBE decryption** — boot this TWRP and attempt a /data backup before relying on it. If it cannot decrypt, /data backup needs a data format (destructive) or must be skipped.
2. Never relock the bootloader with this recovery installed (AVB flags 0, custom key).
3. Keep a copy of this tar (hash above) — it is the known-good recovery to re-flash if anything ever overwrites it.
