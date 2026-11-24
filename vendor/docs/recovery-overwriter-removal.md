# Recovery-overwriter removal (TWRP preservation mechanism)

Mechanism from **Arnav3078/ColorOS17-SM7150**
`scripts/port_coloros.sh` §3 (GPL-3.0), documented in
`research/09b-arnav-ports.md` §2. Credit: Arnav3078 + toraidl.
This doc is OUR write-up of the mechanism for the HyperOS port.

## The problem

Stock Samsung vendor tries to restore stock recovery on boot. If a
port leaves those files in place, the first boot after flashing
overwrites TWRP with the stock recovery — and the user loses their
custom recovery without any warning.

## The mechanism

Delete these three files from the vendor image:
- `recovery-from-boot.p` (the patch that restores stock recovery)
- `bin/install-recovery.sh` (the installer that runs it)
- `etc/init/vendor_flash_recovery.rc` (the init service that
  triggers it)

That is the concrete mechanism behind the standing rule. The rule
("never overwrite the user's installed TWRP recovery") is the
policy; these three deletions are how a port enforces it.

## How to apply it here

1. After assembling the vendor image (L2), delete the three files.
2. Verify: grep the vendor image for `install-recovery` and
   `recovery-from-boot` — zero hits.
3. Verify the flash path: the installer / fastbootd command list
   must flash boot, dtbo, vbmeta and super ONLY — no recovery
   flash anywhere (ColorOS17's `flash_all.sh` is the template:
   boot + dtbo + vbmeta (+ `vbmeta_samsung`) then `super.img`).
4. The same check applies to every zip/script/flash step in this
   project (UN1CA zip, GSI fastbootd steps, kernel boot image):
   no step touches recovery. Arnav's UN1CA installer encodes the
   same rule in code (`rm -f "$TMP_DIR/recovery.img"` with the
   comment "Never package or overwrite user's custom recovery").

## What would break

- Deleting only one or two of the three files: the remaining one
  can still trigger the restore (the .rc starts the script, the
  script applies the .p). All three go, together.
- Forgetting the verification grep: a vendor re-extraction
  (blob refresh from DXJ2) re-introduces the files. The deletion
  must be part of the build, not a one-off edit — put it in the
  build script and check it in the verification record
  (`vendor/scripts/verify_build.py` does not check this; the
  flash checklist in `docs/BUILD-GUIDE.md` does).
