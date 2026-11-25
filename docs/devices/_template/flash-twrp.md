# Flash TWRP - TODO: device name and model

TODO: fill in this file for the new device. Do not copy m51 facts.

## TODO: what TWRP is on this device

- TODO: is TWRP available for this device? Official or unofficial?
  Link the XDA thread.
- TODO: is there a different recovery for this device instead
  (for example LineageOS recovery)? If so, do not write a TWRP
  file. Write the recovery file this device actually uses.

## TODO: verified build

- TODO: TWRP version, build date, Android base, kernel version.
- TODO: is the image verified against a reference build? How was
  it checked? If not verified, say so plainly.
- TODO: fingerprint or build identifier of the verified image, if
  one exists.

## TODO: prereqs

- TODO: bootloader unlocked (link the device's
  unlock-bootloader.md).
- TODO: backup and EFS steps for this device.
- TODO: battery minimum, cable, USB port.
- TODO: model and region check: exact strings to look for.

## TODO: what you need

- TODO: PC OS (Odin is Windows-only; what is the Linux route for
  this device?).
- TODO: USB driver source for this device.
- TODO: Odin version and SHA-256 (verify from a trusted source;
  do not copy the m51 hash).
- TODO: vbmeta file for this device (name, source, which Odin slot).
- TODO: TWRP tar for this device (source link).
- TODO: multidisabler or equivalent for this device, if one is
  needed. If none is needed, say so.

## TODO: steps

- TODO: exact key combination for Download mode on this device.
- TODO: exact Odin slots for vbmeta and TWRP on this device.
  Warning: some guides put vbmeta on the USERDATA slot. That is
  unusual and unverified. Do not copy it without verifying it
  against a real Odin run for this device.
- TODO: the exact step that catches recovery before the system
  boots: key combination and timing for this device.
- TODO: multidisabler step, if needed.
- TODO: Format Data or wipe step: exact TWRP menu path for this
  device, and whether /data encryption must be removed.

## TODO: verify

- TODO: how to check TWRP is installed and which version it is.

## TODO: keeping TWRP (the rules)

- TODO: does the stock AP tar for this device contain
  `recovery.img`? If yes, a full stock flash replaces TWRP. State
  the keep-TWRP routes for this device.
- TODO: recovery-update behaviour on this device (is there a
  broken "update recovery on first boot" flow?).
- TODO: /data decryption in TWRP on this device: proven or not?

## TODO: troubleshooting

- TODO: Odin does not see the phone.
- TODO: TWRP is gone after a boot.
- TODO: stuck on logo after flashing.
- TODO: TWRP asks for a password or cannot mount /data.
