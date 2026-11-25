# Per-device procedures

One folder per device. Each folder holds that device's exact
procedures for unlocking, recovery, root, and flashing, written for
that device only. Nothing here is generic: a step that works on one
Samsung phone can brick another, so every file names its model,
its files, its hashes, and its key combinations.

## Layout

```text
docs/devices/
├── README.md                  # this file
├── _template/                 # empty procedure files for a new device
│   ├── README.md
│   ├── unlock-bootloader.md
│   ├── flash-twrp.md
│   ├── root.md
│   ├── flash-stock.md
│   ├── flash-gsi.md
│   ├── flash-un1ca.md
│   └── flash-kernel.md
└── m51/                       # SM-M515F - Galaxy M51
    ├── README.md              # device card + links
    ├── unlock-bootloader.md
    ├── flash-twrp.md
    ├── root.md
    ├── flash-stock.md
    ├── flash-gsi.md
    ├── flash-un1ca.md
    └── flash-kernel.md
```

## The files in each device folder

| File | Purpose |
|---|---|
| `README.md` | Device card: model, SoC, firmware, recovery, and links to the procedures below. |
| `unlock-bootloader.md` | Unlock the bootloader for this device, once, with the cost stated. |
| `flash-twrp.md` | Flash the custom recovery for this device, and keep it. |
| `root.md` | Root methods that work on this device, with the ones that do not. |
| `flash-stock.md` | Flash the official stock firmware for this device, and get back to stock. |
| `flash-gsi.md` | Flash a GSI (HyperOS) on this device: DSU trial first, full flash second. |
| `flash-un1ca.md` | Flash the UN1CA One UI port on this device. |
| `flash-kernel.md` | Flash the custom kernel for this device. |

Each procedure file is standalone: its own prereqs, steps, verify
step, and troubleshooting, so a reader with only that file can do
the job. A procedure never says "see the other file" for a step
that decides success or failure; it states the step.

## The rule

The per-device file is the canonical copy for that device. The
repo README (`README.md` at the repo root) mirrors the procedures
on a single page. When a procedure changes, update **both** in the
same commit. A fix in one place only is a bug waiting for the next
reader.

## How to add a new device

1. Copy `docs/devices/_template/` to `docs/devices/<codename>/`.
   Use the device codename as the folder name (for example `a71`).
2. Fill in every TODO in every file from that device's own sources:
   the XDA thread, the stock firmware record, the TWRP build, the
   device tree. Do not copy m51 facts into the new folder.
3. Verify every fact you write: model string, SoC, firmware
   version, hashes, key combinations, partition layout. A wrong
   fact in a flash guide is a brick, not a typo.
4. Add the device to the repo root `README.md` §14 tree and to the
   device list below.
5. Run the repo link check before committing: every relative link
   in the new files must point at a file that exists in the repo.

## Devices

| Folder | Device | Model | Status |
|---|---|---|---|
| [m51/](m51/README.md) | Galaxy M51 | SM-M515F | Complete procedures; GSI and UN1CA untested on device |
