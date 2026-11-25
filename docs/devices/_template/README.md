# Template: how to add a new device

Copy this folder to `docs/devices/<codename>/` to add a new device.
Use the device codename as the folder name (for example `a71`).
The fastest start is to copy the `m51` folder instead of this one,
then replace every device fact using the checklist below. This
template folder exists so a new device can also start from blank
files with nothing to delete.

## Checklist: facts that MUST change per device

Every item below is device-specific. Do not copy the m51 value.
Fill each one from the new device's own sources (XDA thread, stock
firmware record, TWRP build, device tree).

- **Model:** model string (for example SM-A715F), codename, folder
  name.
- **SoC:** SoC name and platform. The SoC decides the kernel tree,
  the GSI fit, and the vendor blobs. A guide written for one SoC
  family does not apply to another.
- **Firmware:** latest official firmware for the device's region:
  PDA, CSC, modem, build number, bootloader version, hashes. The
  anti-rollback rule depends on the bootloader version.
- **TWRP build:** version, build date, Android base, and whether
  it is verified against a reference image. A TWRP build for one
  device does not boot on another.
- **GSI fit:** whether the GSI system image fits the device's super
  partition, which logical partitions to delete, and which GSI
  build (spring, gold, pudding) is the default for this device.
- **Partition layout:** dynamic partitions or A-only, super layout,
  boot partition size (the kernel image must fit it), recovery
  partition behaviour.
- **Keys and slots:** Download mode key combination, recovery key
  combination, Odin slots used, vbmeta handling. All of these vary
  by device.
- **Sensors and hardware:** fingerprint position and type, panel
  refresh rate (verify: does the panel really do 120 Hz, or only
  60 Hz?), proximity sensor behaviour, camera stack.
- **Vendor:** the Android version the vendor is frozen at, VNDK
  version, FCM target level, blob count if audited. This decides
  whether HyperOS 2 or 3 is plausible at all.
- **Root methods:** which root methods work on this device
  (Magisk, APatch, KernelSU), and which do not. KernelSU needs a
  KernelSU-enabled kernel for this device.

## Rules for a new device

- Verify every fact you write. A wrong fact in a flash guide is a
  brick, not a typo.
- Keep the same 7 file names. Add files only if the device needs a
  procedure this template does not cover.
- Every relative link you write must point at a file that exists in
  the repo. Check before committing.
- Say plainly what is proven, what is untested, and what has not
  started. Do not present anything as working until it has actually
  run on the phone.
- When the procedures are done, add the device to the table in
  `docs/devices/README.md` and to the repo root `README.md` §14
  tree.

## Files

| File | Purpose |
|---|---|
| `README.md` | This file: how to add a device. (The device card itself lives in each device folder's `README.md`; copy the m51 one as the starting point.) |
| `unlock-bootloader.md` | Unlock the bootloader for the new device. |
| `flash-twrp.md` | Flash the custom recovery for the new device. |
| `root.md` | Root methods that work on the new device. |
| `flash-stock.md` | Flash the official stock firmware for the new device. |
| `flash-gsi.md` | Flash a GSI on the new device. |
| `flash-un1ca.md` | Flash the UN1CA One UI port on the new device (only if a UN1CA target exists for it). |
| `flash-kernel.md` | Flash the custom kernel for the new device (only if a kernel build exists for it). |
