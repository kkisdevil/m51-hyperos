#!/usr/bin/env python3
"""patch_fstab.py — vendor fstab recipe for the HyperOS port (m51).

Applies the fstab recipe from Arnav3078/ColorOS17-SM7150
``scripts/port_coloros.sh`` §3 + ``patch_boot.py`` (GPL-3.0, credited in
vendor/README.md) to a plain fstab file (e.g. the vendor image's
``/vendor/etc/fstab.qcom``):

- ``fileencryption=ice`` -> ``encryptable``
- strip ``,avb`` and ``,avb_keys=<...>`` tokens (verification is
  disabled for the port — vbmeta is flashed with flags 0x03)
- with ``--erofs``: add EROFS entries for system/system_ext/product
  (only for an EROFS GSI; spring is ext4 — do not use for spring)
- with ``--nofail-donor <part>``: append a ``nofail`` entry for a
  donor-only partition (ColorOS used this for its ``my_*`` partitions;
  the HyperOS port has no donor partitions, so this is off by default)

The rules themselves live in patch_boot.py (same directory); this tool
is the file-level front end for them, so the recipe cannot drift
between the boot-image path and the vendor-image path.

Usage:
    python3 patch_fstab.py <fstab> [out] [--erofs]
                        [--nofail-donor my_stock ...] [--dry-run]
    With no <out>, the file is patched in place (a .orig backup is
    written first). --dry-run prints the diff and writes nothing.

Exit codes: 0 ok (changed or already clean), 1 bad input.
"""

import argparse
import difflib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patch_boot import patch_fstab_text  # noqa: E402


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Apply the HyperOS port fstab recipe to a fstab file.")
    ap.add_argument("fstab", help="fstab file to patch")
    ap.add_argument("out", nargs="?", default=None,
                    help="output file (default: patch in place, keep .orig)")
    ap.add_argument("--erofs", action="store_true",
                    help="add EROFS entries for system/system_ext/product")
    ap.add_argument("--nofail-donor", action="append", default=[],
                    metavar="PART",
                    help="append a nofail entry for a donor-only partition "
                         "(repeatable; HyperOS port: do not use)")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the diff, write nothing")
    args = ap.parse_args(argv)

    with open(args.fstab, "r", encoding="utf-8") as f:
        text = f.read()
    new_text, changed = patch_fstab_text(text, erofs=args.erofs)

    if args.nofail_donor:
        lines = new_text.splitlines()
        have = {l.split()[1] for l in lines
                if l and not l.startswith("#") and len(l.split()) > 1}
        for part in args.nofail_donor:
            mount = "/" + part
            if mount not in have:
                lines.append("%s %s erofs ro,nofail,wait,logical"
                             % (part, mount))
                changed += 1
        new_text = "\n".join(lines) + ("\n" if lines else "")

    if args.dry_run:
        diff = difflib.unified_diff(
            text.splitlines(), new_text.splitlines(),
            fromfile=args.fstab, tofile=args.out or args.fstab,
            lineterm="")
        print("\n".join(diff) if new_text != text else "(no changes)")
        print("%d line(s) changed" % changed)
        return 0

    out = args.out or args.fstab
    if args.out is None:
        with open(args.fstab + ".orig", "w", encoding="utf-8") as f:
            f.write(text)
    with open(out, "w", encoding="utf-8") as f:
        f.write(new_text)
    print("%s: %d line(s) changed -> %s" % (args.fstab, changed, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
