# Root - TODO: device name and model

TODO: fill in this file for the new device. Do not copy m51 facts.

## TODO: what root costs on this device

- TODO: Knox behaviour (does this device have Knox?).
- TODO: banking apps and Play Integrity on this device.
- TODO: OTA behaviour on a rooted phone for this device.
- TODO: relock rule for this device.
- TODO: how to unroot on this device (flash stock boot or AP,
  or Magisk Uninstall).

## TODO: prereqs

- TODO: bootloader unlocked (link the device's
  unlock-bootloader.md). Which methods need TWRP?
- TODO: backup and EFS steps.
- TODO: battery minimum, cable, USB port for the Odin steps.
- TODO: model and region check: exact strings to look for.
- TODO: how to find which stock build the phone runs (settings
  path), so the right AP or boot image is patched.

## TODO: Method A (Magisk, patch the AP)

- TODO: Magisk APK source (link the releases page).
- TODO: stock AP tar filename pattern for this device.
- TODO: exact Magisk menu path (Install, Select and Patch a File).
- TODO: patched tar filename and where it lands.
- TODO: Odin slots for the patched tar on this device, and whether
  BL, CP, and CSC from the same package are also needed.
- TODO: Re-Partition and other Odin options for this device.

## TODO: Method B (Magisk, patch the boot image)

- TODO: how to extract `boot.img` from this device's AP tar.
- TODO: Magisk patch step for the boot image.
- TODO: how to flash the patched boot image on this device (TWRP
  Install Image to Boot, or another route).

## TODO: Method C (Magisk zip in TWRP)

- TODO: does this method work on this device? If the device has
  no TWRP, delete this method.
- TODO: exact TWRP steps.

## TODO: verify

- TODO: the check that proves root works on this device (Magisk
  app state, `adb shell su -c id` output).

## TODO: other root methods

- TODO: APatch: does it work on this device? Has anyone run it
  end-to-end on this device? Say so plainly.
- TODO: KernelSU: does a KernelSU-enabled kernel exist for this
  device? If not, say it is not recommended.
- TODO: any other root tool recommended for this device, with the
  source and the warning attached.
- TODO: any optimizer or module that fights this project's fixes
  on this device (name it and say not to install it).

## TODO: after root

- TODO: module installation path for this device.
- TODO: banking app failures: Play Integrity note for this device.
- TODO: OTA warning for this device.
- TODO: bootloader partition warning for this device.

## TODO: troubleshooting

- TODO: Magisk shows "Installed: N/A".
- TODO: `su` is denied.
- TODO: bootloop after flashing a patched image (and the rollback:
  flash stock `boot.img` to Boot).
- TODO: banking app fails after root.
