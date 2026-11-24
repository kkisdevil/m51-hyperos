#!/usr/bin/env python3
"""patch_boot.py — permissive boot image + ramdisk fstab patcher (m51).

Our own implementation of the pattern from Arnav3078/ColorOS17-SM7150
``scripts/patch_boot.py`` (GPL-3.0, credited in vendor/README.md):
parse a boot image header (v1/v2), append
``androidboot.selinux=permissive`` to the cmdline, gunzip the ramdisk,
walk the CPIO (newc) entries, patch the fstab files, rebuild + re-gzip.

Differences from the ColorOS original (this is OUR tool, not a copy):
- No ColorOS / OPPO assumptions: no ``my_*`` donor partitions are added
  unless ``--erofs`` is given, and even then only system/system_ext/
  product get EROFS entries (spring is ext4 — see docs/gsi-verification.md).
- No KernelSU, no root baked in: this only makes the boot image
  permissive so the HyperOS port can boot for triage (Phase 1).
- Refuses boot images whose header version is not 1 or 2, instead of
  guessing the layout.
- Warns (does not fail) when no fstab is found in the ramdisk — same
  behaviour as the original, so a ramdisk without fstab does not kill
  a build that only needed the permissive cmdline.

Usage:
    python3 patch_boot.py <boot.img> <out.img> [--no-permissive]
                        [--erofs] [--dry-run]

The output image keeps the original page size and segment layout; only
the cmdline, the ramdisk contents (fstab files) and the ramdisk size
change. The kernel, dtb, dtbo and second stage are copied byte-identical.

Exit codes: 0 ok, 1 bad input / unsupported image, 2 tool error.
"""

import argparse
import gzip
import hashlib
import io
import struct
import sys

MAGIC = b"ANDROID!"
# Boot image header v2 layout (AOSP bootimg.h). v1 is identical up to
# extra_cmdline; v2 adds recovery_dtbo_size/offset, header_size,
# dtb_size/dtb_addr. Header size on disk is always one page.
_HDR_V1 = struct.Struct("<8s10I16s512s8I1024s")
_HDR_V2_EXTRA = struct.Struct("<IQIIQ")


def _align(n, page):
    return (n + page - 1) // page * page


class BootImageError(Exception):
    pass


def parse_header(data):
    """Return a dict describing the boot image header (v1 or v2)."""
    if len(data) < 8 or data[:8] != MAGIC:
        raise BootImageError("not an Android boot image (bad magic)")
    if len(data) < _HDR_V1.size:
        raise BootImageError("file too small for a boot image header")
    fields = _HDR_V1.unpack_from(data, 0)
    # 8s + 10I + 16s + 512s + 8I + 1024s = 22 values (the 8I id
    # expands to 8); the starred target collects exactly those 8.
    (magic, kernel_size, kernel_addr, ramdisk_size, ramdisk_addr,
     second_size, second_addr, tags_addr, page_size, header_version,
     os_version, name, cmdline, *_ids, extra_cmdline) = fields
    if page_size == 0 or page_size & (page_size - 1):
        raise BootImageError("page_size %d is not a power of two" % page_size)
    if header_version not in (0, 1, 2):
        raise BootImageError(
            "unsupported header version %d (this tool handles 1 and 2)"
            % header_version)
    hdr = {
        "version": header_version,
        "page_size": page_size,
        "kernel_size": kernel_size,
        "ramdisk_size": ramdisk_size,
        "second_size": second_size,
        "cmdline": cmdline.rstrip(b"\x00").decode("ascii", "replace"),
        "extra_cmdline": extra_cmdline.rstrip(b"\x00").decode("ascii", "replace"),
        "name": name.rstrip(b"\x00").decode("ascii", "replace"),
    }
    if header_version == 2:
        extra = _HDR_V2_EXTRA.unpack_from(data, _HDR_V1.size)
        (recovery_dtbo_size, recovery_dtbo_offset, header_size,
         dtb_size, dtb_addr) = extra
        hdr.update({
            "recovery_dtbo_size": recovery_dtbo_size,
            "recovery_dtbo_offset": recovery_dtbo_offset,
            "header_size": header_size,
            "dtb_size": dtb_size,
            "dtb_addr": dtb_addr,
        })
    else:
        hdr.update({
            "recovery_dtbo_size": 0,
            "recovery_dtbo_offset": 0,
            "header_size": _HDR_V1.size,
            "dtb_size": 0,
            "dtb_addr": 0,
        })
    return hdr


def segments(hdr):
    """Return [(name, offset, size)] for every segment, in image order."""
    page = hdr["page_size"]
    off = page  # header occupies the first page
    segs = []
    for name, size in (("kernel", hdr["kernel_size"]),
                       ("ramdisk", hdr["ramdisk_size"]),
                       ("second", hdr["second_size"]),
                       ("recovery_dtbo", hdr["recovery_dtbo_size"]),
                       ("dtb", hdr["dtb_size"])):
        segs.append((name, off, size))
        off += _align(size, page)
    return segs


# ---------------------------------------------------------------- CPIO (newc)

def _cpio_read(data):
    """Parse a newc CPIO archive. Returns [(name, mode, data_bytes)]."""
    entries = []
    off = 0
    while off + 110 <= len(data):
        if data[off:off + 6] != b"070701":
            raise BootImageError(
                "ramdisk is not newc CPIO (bad magic at offset %d)" % off)
        fields = data[off + 6:off + 110].decode("ascii")
        # 13 x 8-hex-digit fields: ino, mode, uid, gid, nlink, mtime,
        # filesize, devmajor, devminor, rdevmajor, rdevminor, namesize, check
        vals = [int(fields[i * 8:(i + 1) * 8], 16) for i in range(13)]
        _ino, mode, _uid, _gid, _nlink, _mtime, filesize, _dmaj, _dmin, \
            _rmaj, _rmin, namesize, _check = vals
        name_off = off + 110
        name = data[name_off:name_off + namesize - 1].decode("utf-8", "replace")
        data_off = _align(name_off + namesize, 4)
        entries.append((name, mode, data[data_off:data_off + filesize]))
        off = _align(data_off + filesize, 4)
        if name == "TRAILER!!!":
            break
    return entries


def _cpio_write(entries):
    """Serialise [(name, mode, data_bytes)] as a newc CPIO archive."""
    out = bytearray()
    for name, mode, blob in entries:
        name_b = name.encode("utf-8") + b"\x00"
        hdr = b"070701" + b"".join(
            ("%08x" % v).encode("ascii") for v in (
                0,            # ino
                mode,         # mode
                0, 0,         # uid, gid
                1 if (mode & 0o170000) == 0o100000 else 0,  # nlink
                0,            # mtime
                len(blob),    # filesize
                0, 0, 0, 0,   # dev/rdev major/minor
                len(name_b),  # namesize
                0,            # check
            ))
        out += hdr
        out += name_b
        while len(out) % 4:
            out += b"\x00"
        out += blob
        while len(out) % 4:
            out += b"\x00"
    # trailer
    trailer = b"TRAILER!!!\x00"
    hdr = b"070701" + b"".join(("%08x" % v).encode("ascii") for v in (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, len(trailer), 0))
    out += hdr
    out += trailer
    while len(out) % 4:
        out += b"\x00"
    return bytes(out)


# ---------------------------------------------------------------- fstab rules

FSTAB_NAMES = ("fstab.default", "fstab.qcom", "fstab.sm7150",
               "fstab.ramplus", "fstab.emmc")


def patch_fstab_text(text, erofs=False):
    """Apply the vendor fstab recipe to one fstab file's text.

    - ``fileencryption=ice`` -> ``encryptable`` (stock Samsung vendor
      uses inline crypto encryption; the GSI's fstab must not demand ICE
      on a vendor that does not offer it that way).
    - Strip ``,avb`` and ``,avb_keys=<...>`` tokens (verification is
      disabled for the port — vbmeta is flashed with flags 0x03).
    - With erofs=True, add EROFS entries for system/system_ext/product
      (only for an EROFS GSI; spring is ext4, so this is off by default).
    Returns (new_text, changed_lines).
    """
    changed = 0
    out_lines = []
    for line in text.splitlines():
        new = line
        if "fileencryption=ice" in new:
            new = new.replace("fileencryption=ice", "encryptable")
            changed += 1
        if ",avb_keys=" in new:
            # strip the avb_keys token up to the next comma or EOL
            parts = new.split(",avb_keys=")
            new = parts[0]
            rest = parts[1]
            if "," in rest:
                new += "," + rest.split(",", 1)[1]
            changed += 1
        if ",avb" in new:
            new = new.replace(",avb", "")
            changed += 1
        out_lines.append(new)
    if erofs:
        have = {l.split()[1] for l in out_lines
                if l and not l.startswith("#") and len(l.split()) > 1}
        for mount, part in (("/system", "system"),
                            ("/system_ext", "system_ext"),
                            ("/product", "product")):
            if mount not in have:
                out_lines.append(
                    "%s /%s erofs ro,wait,logical,first_stage_mount" % (part, part))
                changed += 1
    return "\n".join(out_lines) + ("\n" if out_lines else ""), changed


def patch_ramdisk(ramdisk_gz, erofs=False):
    """Gunzip the ramdisk, patch its fstab files, re-gzip.

    Returns (new_ramdisk_gz, patched_files, warned). ``warned`` is True
    when no fstab was found — the caller reports it, but it is not an
    error (same behaviour as the ColorOS original).
    """
    raw = gzip.decompress(ramdisk_gz)
    entries = _cpio_read(raw)
    patched = []
    new_entries = []
    for name, mode, blob in entries:
        base = name.rsplit("/", 1)[-1]
        if base in FSTAB_NAMES:
            try:
                text = blob.decode("utf-8")
            except UnicodeDecodeError:
                new_entries.append((name, mode, blob))
                continue
            new_text, changed = patch_fstab_text(text, erofs=erofs)
            if changed:
                patched.append((name, changed))
                new_entries.append((name, mode, new_text.encode("utf-8")))
            else:
                new_entries.append((name, mode, blob))
        else:
            new_entries.append((name, mode, blob))
    return gzip.compress(_cpio_write(new_entries), mtime=0), patched, not patched


def patch_cmdline(cmdline, extra_cmdline, permissive=True):
    """Append androidboot.selinux=permissive if missing (v2: extra_cmdline)."""
    if not permissive:
        return cmdline, extra_cmdline, False
    token = "androidboot.selinux=permissive"
    if token in cmdline or token in extra_cmdline:
        return cmdline, extra_cmdline, False
    # v2 images keep the main cmdline short; append to extra_cmdline.
    new_extra = (extra_cmdline + " " + token).strip()
    return cmdline, new_extra, True


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Make a permissive boot image + patch ramdisk fstab (m51).")
    ap.add_argument("image", help="input boot.img")
    ap.add_argument("output", help="output boot.img")
    ap.add_argument("--no-permissive", action="store_true",
                    help="do not append androidboot.selinux=permissive")
    ap.add_argument("--erofs", action="store_true",
                    help="add EROFS fstab entries for system/system_ext/product "
                         "(only for an EROFS GSI; spring is ext4, do not use)")
    ap.add_argument("--dry-run", action="store_true",
                    help="report what would change, write nothing")
    args = ap.parse_args(argv)

    with open(args.image, "rb") as f:
        data = f.read()
    hdr = parse_header(data)
    page = hdr["page_size"]
    segs = dict((n, (o, s)) for n, o, s in segments(hdr))
    ram_off, ram_size = segs["ramdisk"]
    ramdisk = data[ram_off:ram_off + ram_size]

    new_cmdline, new_extra, cmd_changed = patch_cmdline(
        hdr["cmdline"], hdr["extra_cmdline"], permissive=not args.no_permissive)
    new_ramdisk, patched, warned = patch_ramdisk(ramdisk, erofs=args.erofs)

    print("boot image: header v%d, page %d, name %r"
          % (hdr["version"], page, hdr["name"]))
    print("cmdline:    %s" % ("+ androidboot.selinux=permissive"
                              if cmd_changed else "unchanged"))
    for name, n in patched:
        print("fstab:      %s (%d lines changed)" % (name, n))
    if warned:
        print("warning:    no fstab found in ramdisk — cmdline only "
              "(this is not an error)")
    if args.dry_run:
        print("dry-run:    nothing written")
        return 0

    # Rebuild: header page (cmdline fields rewritten in place), then the
    # segments in order, each page-aligned. Kernel/dtb/dtbo/second are
    # copied byte-identical; only the ramdisk bytes change.
    out = bytearray(data[:page])
    if cmd_changed:
        # Header layout (AOSP bootimg.h): magic 0-7, kernel_size 8,
        # ramdisk_size 16, cmdline 64-575 (512 bytes), id 576-607,
        # extra_cmdline 608-1631 (1024 bytes). v2 extra fields follow
        # at 1632; the total v2 header is 1660 bytes.
        out[64:64 + 512] = new_cmdline.encode("ascii")[:512].ljust(512, b"\x00")
        out[608:608 + 1024] = new_extra.encode("ascii")[:1024].ljust(1024, b"\x00")
    # ramdisk_size field lives at offset 16 in the header.
    struct.pack_into("<I", out, 16, len(new_ramdisk))

    for name, off, size in segments(hdr):
        blob = new_ramdisk if name == "ramdisk" else data[off:off + size]
        out += blob
        pad = _align(len(blob), page) - len(blob)
        out += b"\x00" * pad

    with open(args.output, "wb") as f:
        f.write(bytes(out))
    print("wrote:      %s (%d bytes, sha256 %s)"
          % (args.output, len(out),
             hashlib.sha256(bytes(out)).hexdigest()[:16]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
