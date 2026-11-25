# Flash the stock ROM - TODO: device name and model

TODO: fill in this file for the new device. Do not copy m51 facts.

## TODO: when to use this

- TODO: the cases where a stock flash is the right move for this
  device (unbrick, undo a bad flash, known-good base, bootloop
  TWRP cannot fix).
- TODO: what a stock flash removes on this device (root, custom
  ROM, custom recovery).
- TODO: Knox behaviour on this device (does flashing stock untrip
  it? On Samsung it does not: confirm for this device).

## TODO: what you are flashing

TODO: fill in the table from the device's own firmware record.
Verify every value. Do not copy m51 values.

| Field | Value |
|---|---|
| Model / region | TODO: model and CSC region |
| PDA / AP | TODO |
| Modem / CP | TODO |
| Build number | TODO |
| Android / One UI | TODO: Android version, One UI version, patch date, changelist |
| Build date | TODO |
| Bootloader | TODO: version, and the anti-rollback rule for this device |
| Server file | TODO: exact server filename and byte size |
| MD5 | TODO |
| SHA-256 | TODO |

TODO: is this the latest official firmware for this device's
region? How was that checked? Where is the file (Drive path or
other mirror)? Link the firmware record doc if one exists.

## TODO: prereqs

- TODO: PC OS (Odin is Windows-only; Linux route for this device?).
- TODO: USB driver source for this device.
- TODO: Odin version and SHA-256 (verify from a trusted source;
  do not copy the m51 hash). Note any disputed version for this
  device.
- TODO: cable, USB port, battery minimum.
- TODO: backup and EFS steps for this device.
- TODO: model and region check: exact strings to look for.

## TODO: the files in the firmware zip

TODO: list every `.tar.md5` in this device's firmware zip, with
its Odin slot and what it is. Note which file wipes data (CSC)
and which keeps it (HOME_CSC), if this device's package has both.

## TODO: steps

- TODO: Download mode key combination for this device.
- TODO: Odin as administrator, `ID:COM` check.
- TODO: slot loading order and the MD5 wait for this device.
- TODO: Odin options: which stay ticked, which stay unticked
  (Re-Partition warning).
- TODO: Start, PASS, first boot, and the build number check.

## TODO: verify

- TODO: build number check and signal and region check for this
  device.

## TODO: keeping TWRP through a stock flash

- TODO: does this device's stock AP tar contain `recovery.img`?
  If yes, a full stock AP replaces TWRP. State the keep-TWRP
  routes for this device (remove `recovery.img` from the AP tar,
  or re-flash TWRP before the first boot into system).
- TODO: recovery key combination for this device.

## TODO: troubleshooting

- TODO: Odin does not detect the phone.
- TODO: Odin shows FAIL.
- TODO: `SW REV CHECK FAIL` (anti-rollback rule for this device).
- TODO: stuck on logo or bootloop after flashing.
- TODO: no signal or wrong region features.
- TODO: TWRP is gone after the flash.
