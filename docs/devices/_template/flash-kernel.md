# Flash the custom kernel - TODO: device name and model

TODO: fill in this file for the new device. Do not copy m51 facts.
Delete this file if no kernel build exists for this device.

## TODO: boot test warning

- TODO: has the kernel booted on this device? If not, say so
  prominently at the top of this file, exactly as the m51 file
  does. A green build is not a booting kernel.

## TODO: what the kernel is

- TODO: kernel source (repo, branch, version), defconfig name,
  EROFS support, SELinux mode.
- TODO: latest build number, run id, artifact name, size,
  SHA-256, retention.
- TODO: which build gates exist for this device and which passed.

## TODO: how it was built

- TODO: toolchain (name, commit, version).
- TODO: defconfig handling (merged or reviewed savedefconfig?
  How many CONFIG lines?).
- TODO: patches applied for this device, and the bugs fixed along
  the way (name them: do not copy another tree's build scripts
  blindly if they carry the same bugs).

## TODO: prereqs

- TODO: TWRP installed (link the device's flash-twrp.md).
- TODO: backup and EFS steps.
- TODO: keep the old boot image on the phone before flashing the
  new one (how to get it for this device).
- TODO: battery minimum.
- TODO: model check.
- TODO: the kernel artifact, extracted to the boot image, with
  its SHA-256 checked.

## TODO: steps

- TODO: exact TWRP Install Image steps for this device (which
  partition: Boot).
- TODO: or the Odin route for this device (boot.tar in which slot?).
- TODO: confirm only the boot partition is written and recovery
  is untouched.

## TODO: verify

- TODO: `uname -a` and `/proc/version` checks for this device.
- TODO: the checks that prove the phone works after the flash
  (Wi-Fi, calls, sensors).
- TODO: how to record the first boot result (Gate 8) for this
  device.

## TODO: rollback

- TODO: exact rollback steps for this device (re-flash the old
  boot image from TWRP, or flash stock boot from the stock AP tar,
  or flash full stock firmware).

## TODO: troubleshooting

- TODO: bootloop after flashing (do not wipe data first: say why).
- TODO: kernel version string is wrong.
- TODO: Wi-Fi or sensors broke after flashing.
- TODO: image too large for the boot partition (state the boot
  partition size for this device).
