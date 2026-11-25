# Flash HyperOS (GSI) - TODO: device name and model

TODO: fill in this file for the new device. Do not copy m51 facts.

## TODO: what a GSI is on this device

- TODO: is there a device-specific HyperOS port for this device?
  If yes, this file is the wrong place: link the port instead.
- TODO: does XMAPort work for this device? (It needs an official
  HyperOS base ROM for the target. If the device has none, say so.)
- TODO: the proven route for this device (GSI, or something else),
  and the evidence for it (which sibling device boots it, which
  reports exist, linked or user-reported).

## TODO: honest status

- TODO: has HyperOS booted on this device in front of us? If not,
  say so. Has the DSU trial started? Say so.

## TODO: the GSI builds

TODO: table of the GSI builds for this device (file, size,
system). Which build is the default for this device, and why?
Verify sizes and MD5s from the source listing. Note which donor
SoC each build comes from and whether that matters for this
device's vendor.

## TODO: prereqs

- TODO: bootloader unlocked (link the device's
  unlock-bootloader.md).
- TODO: backup and EFS steps.
- TODO: battery minimum, cable, USB port.
- TODO: model and region check.
- TODO: TWRP installed (link the device's flash-twrp.md) for the
  full flash.
- TODO: PC with platform-tools, free disk, GSI file size.
- TODO: free space needed on the phone for the DSU trial.

## TODO: Part 1 (DSU trial boot)

- TODO: DSU Sideloader source for this device (F-Droid or GitHub
  releases), and Shizuku or root or ADB mode.
- TODO: exact DSU Sideloader steps for this device (permissions,
  file selection, install, confirm, boot).
- TODO: sticky mode command for this device.
- TODO: what a DSU boot proves and does not prove on this device.
- TODO: DSU failure modes for this device (AVB block, free space,
  bootloop) and the fix for each.

## TODO: Part 2 (full flash, TWRP + fastbootd)

- TODO: does this device have native fastboot? If not, the
  fastbootd route through TWRP applies. State it.
- TODO: Permissiver version for this device (verified URL, size,
  MD5) or the SELinux step this device needs.
- TODO: exact fastboot commands for this device, including which
  logical partitions to delete and why. Verify the super layout:
  does the GSI fit? What happens if it does not?
- TODO: Format Data step and first boot notes for this device.
- TODO: setup wizard behaviour on this device (dead? working?)
  and the setup-skip commands if needed.
- TODO: boot log capture for this device (live watcher or logcat).

## TODO: verify

- TODO: the checks that prove the GSI works on this device (home
  screen, Wi-Fi, calls, data, fingerprint, camera, brightness).
  Say which ones are proven by a boot alone (none of them, except
  the boot itself).

## TODO: going back to stock

- TODO: link the device's flash-stock.md and state what the
  rollback restores and what it does not (Knox).

## TODO: troubleshooting

- TODO: DSU installs but will not boot.
- TODO: DSU install fails.
- TODO: GSI black screen or bootloop.
- TODO: `fastboot flash system` size error.
- TODO: setup wizard dead.
- TODO: no SIM, no calls, no data on this device.
