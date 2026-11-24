#!/usr/bin/env python3
"""make_fixtures.py — build synthetic fixtures for the vendor tests.

Creates small, fake inputs under <out-dir> so the vendor tools can be
tested without any real firmware, GSI, or device:

- boot-v2.img: a fake Android boot image, header v2, page 2048, with a
  gzipped newc CPIO ramdisk containing fstab.sm7150 (with the ICE/AVB
  patterns the patcher must rewrite) and a plain file.
- fstab.qcom: a fake vendor fstab with the same patterns.
- matrix.5.xml / manifest.xml: a fake framework matrix + vendor
  manifest (one missing mandatory HAL -> FAIL, one optional missing
  HAL, one unparseable version -> UNCHECKED).
- stock/: a fake stock firmware tree (build.prop, fstab, floating
  feature, VINTF manifest, dvfs dir) for auto_gen_facts.py.
- sysfs/: a fake /sys with panel0-backlight reading brightness=100,
  actual_brightness=0, bl_power=1, max_brightness=13510 (dark panel).
- build-out/: a fake build output dir (two files + a zip) for
  verify_build.py, plus hashes.json with the correct SHA-256s.

Usage: python3 make_fixtures.py <out-dir>
"""

import gzip
import hashlib
import os
import shutil
import struct
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "scripts"))
from patch_boot import _cpio_write  # noqa: E402


def align(n, page):
    return (n + page - 1) // page * page


def make_boot_image(path):
    page = 2048
    fstab = (
        "/dev/block/bootdevice/by-name/system /system ext4 "
        "ro,wait,avb,avb_keys=/avb/q-gsi.avbpubkey,fileencryption=ice\n"
        "/dev/block/bootdevice/by-name/vendor /vendor ext4 "
        "ro,wait,avb,fileencryption=ice\n"
        "/dev/block/bootdevice/by-name/product /product ext4 ro,wait,avb\n"
    )
    ramdisk = gzip.compress(_cpio_write([
        ("fstab.sm7150", 0o100644, fstab.encode("utf-8")),
        ("init", 0o100755, b"#!/bin/sh\n"),
    ]), mtime=0)
    kernel = b"FAKEKERNEL" * 10
    dtb = b"FAKEDTB" * 4

    # v2 header: 8s + 10I + 16s + 512s + 8I + 1024s + (I Q I I Q)
    hdr = struct.pack(
        "<8s10I16s512s8I1024sIQIIQ",
        b"ANDROID!",
        len(kernel), 0x80008000,
        len(ramdisk), 0x81000000,
        0, 0x00000000,
        0x00000000, page, 2, 0,
        b"m51-test\x00\x00\x00\x00\x00\x00\x00\x00",
        b"androidboot.hardware=qcom",
        *(0,) * 8,
        b"",
        0, 0, 1660, len(dtb), 0x00000000,
    )
    assert len(hdr) == 1660, len(hdr)
    out = bytearray(hdr)
    out += b"\x00" * (page - len(out))
    for blob in (kernel, ramdisk, dtb):
        out += blob
        out += b"\x00" * (align(len(blob), page) - len(blob))
    with open(path, "wb") as f:
        f.write(bytes(out))
    return path


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)

    make_boot_image(os.path.join(out_dir, "boot-v2.img"))

    with open(os.path.join(out_dir, "fstab.qcom"), "w") as f:
        f.write(
            "/dev/block/bootdevice/by-name/system /system ext4 "
            "ro,wait,avb,avb_keys=/avb/q-gsi.avbpubkey,fileencryption=ice\n"
            "/dev/block/bootdevice/by-name/vendor /vendor ext4 "
            "ro,wait,avb,fileencryption=ice\n")

    with open(os.path.join(out_dir, "matrix.5.xml"), "w") as f:
        f.write("""<compatibility-matrix version="5.0" type="framework">
  <hal format="hidl" optional="false">
    <name>android.hardware.camera.provider</name>
    <version>2.6</version>
  </hal>
  <hal format="hidl" optional="false">
    <name>android.hardware.light</name>
    <version>2.0</version>
  </hal>
  <hal format="hidl" optional="false">
    <name>android.hardware.biometrics.fingerprint</name>
    <version>2.1</version>
  </hal>
  <hal format="hidl" optional="false">
    <name>android.hardware.foo</name>
    <version>9.9</version>
  </hal>
  <hal format="hidl" optional="true">
    <name>android.hardware.bar</name>
    <version>1.0</version>
  </hal>
  <hal format="hidl" optional="false">
    <name>android.hardware.baz</name>
    <version>x</version>
  </hal>
</compatibility-matrix>
""")

    with open(os.path.join(out_dir, "manifest.xml"), "w") as f:
        f.write("""<manifest version="1.0" type="device" target-level="6">
  <hal format="hidl">
    <name>android.hardware.camera.provider</name>
    <transport>hwbinder</transport>
    <version>2.6</version>
  </hal>
  <hal format="hidl">
    <name>android.hardware.light</name>
    <transport>hwbinder</transport>
    <version>2.0</version>
  </hal>
  <hal format="hidl">
    <name>android.hardware.biometrics.fingerprint</name>
    <transport>hwbinder</transport>
    <version>2.1</version>
  </hal>
</manifest>
""")

    stock = os.path.join(out_dir, "stock")
    for d in ("system", "vendor/etc", "vendor/etc/vintf",
              "vendor/etc/dvfs", "system/etc"):
        os.makedirs(os.path.join(stock, d), exist_ok=True)
    with open(os.path.join(stock, "system/build.prop"), "w") as f:
        f.write("ro.product.model=SM-M515F\nro.product.device=m51\n"
                "ro.build.version.sdk=31\n"
                "ro.build.fingerprint=samsung/m51/m51:12/SP1A.210812.016/"
                "M515FXXU6DXJ2:user/release-keys\n"
                "ro.build.version.security_patch=2024-05-01\n")
    with open(os.path.join(stock, "vendor/build.prop"), "w") as f:
        f.write("ro.hardware=qcom\nro.vendor.build.version.sdk=31\n"
                "ro.vndk.version=31\n")
    with open(os.path.join(stock, "vendor/etc/fstab.qcom"), "w") as f:
        f.write("/dev/block/bootdevice/by-name/system /system ext4 ro,wait\n"
                "/dev/block/bootdevice/by-name/vendor /vendor ext4 ro,wait\n")
    with open(os.path.join(stock, "system/etc/floating_feature.xml"), "w") as f:
        f.write('<SEC_FLOATING_FEATURE_FEATURE_HFR_DEFAULT_REFRESH_RATE>60'
                '</SEC_FLOATING_FEATURE_FEATURE_HFR_DEFAULT_REFRESH_RATE>\n'
                '<SEC_FLOATING_FEATURE_FEATURE_HFR_MODE>0'
                '</SEC_FLOATING_FEATURE_FEATURE_HFR_MODE>\n')
    shutil.copy(os.path.join(out_dir, "manifest.xml"),
                os.path.join(stock, "vendor/etc/vintf/manifest.xml"))
    open(os.path.join(stock, "vendor/etc/dvfs/siop_m51_sm7150.xml"), "w").close()

    sysfs = os.path.join(out_dir, "sysfs/class/backlight/panel0-backlight")
    os.makedirs(sysfs, exist_ok=True)
    for name, value in (("brightness", "100"), ("actual_brightness", "0"),
                        ("bl_power", "1"), ("max_brightness", "13510")):
        with open(os.path.join(sysfs, name), "w") as f:
            f.write(value + "\n")

    build_out = os.path.join(out_dir, "build-out")
    os.makedirs(build_out, exist_ok=True)
    hashes = {}
    for name, content in (("system.img", b"FAKESYSTEM" * 100),
                          ("vbmeta.img", b"FAKEVBMETA")):
        p = os.path.join(build_out, name)
        with open(p, "wb") as f:
            f.write(content)
        hashes[name] = hashlib.sha256(content).hexdigest()
    zip_path = os.path.join(build_out, "port.zip")
    with zipfile.ZipFile(zip_path, "w") as z:
        z.writestr("hello.txt", "hello\n")
    with open(zip_path, "rb") as f:
        hashes["port.zip"] = hashlib.sha256(f.read()).hexdigest()
    with open(os.path.join(out_dir, "hashes.json"), "w") as f:
        f.write(__import__("json").dumps(hashes, indent=2))

    print("fixtures written to %s" % out_dir)


if __name__ == "__main__":
    main()
