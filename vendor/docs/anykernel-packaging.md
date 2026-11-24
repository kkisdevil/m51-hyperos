# AnyKernel3 packaging pattern (LostPrime)

Pattern from **kurtnettle/android_kernel_samsung_sm7150** `build.sh`
+ `anykernel.sh` (NOASSERTION license; the kernel code itself is
GPL-2.0), documented in `research/09c-arnav-stars.md` §1. Credit:
kurtnettle + pascua28. This doc is OUR write-up of the pattern for
the HyperOS port's kernel zips — not a copy of their scripts.

## The pattern

Package a kernel as a flashable AnyKernel3 zip:
- `Image` (plain, NOT `Image.gz-dtb` — LostPrime's packaging uses
  the plain Image + separate dtb) + `dtb` + `dtbo.img` in the
  AnyKernel3 directory.
- Device names set in `anykernel.sh`: `device.name1=m51`,
  `device.name2=m51nsxx`.
- `anykernel.sh` writes `/dev/block/bootdevice/by-name/boot` only
  (`dump_boot` / `write_boot`). **Recovery untouched** — safe to
  flash via TWRP.

## How this differs from our kernel build

Our kernel build (`.github/workflows/build-kernel.yml`) outputs
`Image.gz-dtb` (the image the 64 MB boot partition boots) as a
GitHub artifact — it is NOT packaged as a flashable zip. The
AnyKernel3 pattern applies when a kernel zip is wanted (e.g. a
kernel-only OTA, or a test kernel flashed from TWRP without
reflashing the whole ROM). If that is ever needed: take the
AnyKernel3 template (osm0sis/AnyKernel3, GPL-3.0), put the built
`Image` + dtb + dtbo in it, set the device names, and verify the
anykernel.sh writes boot only.

## The build.sh assembly pattern (also borrowable)

LostPrime's `build.sh` assembles the defconfig as
`cat sdmmagpie_defconfig + <device>.config > temp_defconfig`,
appends `CONFIG_THINLTO=y` + `CONFIG_LTO_CLANG=y`, and builds with
`LLVM=1 LLVM_IAS=1`, `CROSS_COMPILE=aarch64-linux-gnu-`, PATH
prepended with the clang `bin/`. Two notes for our build:
- Our merged defconfig already carries what we need
  (`kernel/m51_defconfig`, reviewed savedefconfig from run #8) —
  the assembly pattern is a reference, not a replacement.
- **ThinLTO is evaluate-only.** LTO changes codegen on 4.14 and
  could break drivers; test on a throwaway build first, never
  adopt it in a release build without a boot test.

## What would break

- Packaging `Image.gz-dtb` into an AnyKernel3 zip that expects a
  plain `Image`: the flash writes the wrong format and the device
  bootloops. Match the image format to the packager's expectation.
- A secret toolchain: LostPrime's clang (r596125) comes from a
  secret URL (`secrets.TOOLCHAIN_DDL`) that cannot be reproduced.
  Our kernel uses proton-clang (public pin `9fb011b1`) — never
  switch to a toolchain nobody else can fetch.
- The Nov 11 LostPrime release is self-flagged corrupted — never
  use it as a kernel source.
