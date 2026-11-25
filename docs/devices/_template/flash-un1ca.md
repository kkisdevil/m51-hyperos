# Flash UN1CA - TODO: device name and model

TODO: fill in this file for the new device. Do not copy m51 facts.
Delete this file if no UN1CA target exists for this device.

## TODO: what UN1CA is on this device

- TODO: does a UN1CA target exist for this device? Which branch
  and version? Link the repo and the target.
- TODO: what the UN1CA build for this device is based on (donor
  firmware, One UI version).

## TODO: build status (honest)

- TODO: latest build number, run id, duration, artifact name,
  size, SHA-256, retention, download-by date.
- TODO: signing keys (test keys or real keys?).
- TODO: has it been flashed or tested on this device? If not, say
  so plainly.

## TODO: what the zip does

- TODO: does the zip flash bootloader or modem firmware for this
  device? Which versions?
- TODO: does it wipe fingerprint enrolments or dalvik-cache?
- TODO: bootloader assertion (minimum version) for this device.
- TODO: does it touch recovery? (It must not. Verify from the
  installer script, do not assume.)

## TODO: the fix pack (if one exists for this device)

- TODO: what lags on this device, and what the fix pack changes
  (thermal caps, blur, zram, swappiness, daemon overrides).
- TODO: what is kept and what is removed, by the user's rule.

## TODO: how the build is made

- TODO: firmware download tool and version for this device.
- TODO: target pin (repo, branch, commit).
- TODO: OTA system for this device, if one exists.

## TODO: prereqs

- TODO: TWRP installed (link the device's flash-twrp.md).
- TODO: backup and EFS steps.
- TODO: battery minimum.
- TODO: model and region check.
- TODO: minimum bootloader version for this device.
- TODO: the UN1CA zip and its SHA-256, checked against the build
  record.

## TODO: steps

- TODO: Format Data rule for this device (when coming from stock
  or another ROM vs updating from an older UN1CA).
- TODO: exact TWRP install steps for this device.
- TODO: first boot and dexopt wait for this device.

## TODO: verify

- TODO: the checks that prove the fix pack landed on this device
  (effective swappiness value, refresh rate, thermal behaviour).
- TODO: version check in Settings.

## TODO: troubleshooting

- TODO: installer refuses with a bootloader assertion.
- TODO: bootloop after flashing.
- TODO: fix values wrong at runtime (for example swappiness reads
  the wrong value: which daemon overrides it on this device?).
- TODO: fingerprint enrolments gone after flashing.

## TODO: going back to stock

- TODO: link the device's flash-stock.md.
