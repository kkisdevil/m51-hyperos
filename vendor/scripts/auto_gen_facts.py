#!/usr/bin/env python3
"""auto_gen_facts.py — derive device facts from a stock firmware tree.

Our own implementation of the pattern from SameerAlSahab/ProjectArcadeX
``scripts/main/auto_gen.sh`` (MIT, credited in vendor/README.md):
instead of hand-writing a device config, read the facts from the
stock firmware's own files — build.prop, fstab, floating_feature.xml,
the vendor VINTF manifest, the dvfs directory listing.

What it reads (all paths relative to a stock firmware tree root, e.g.
an extracted AP tar or a ``system/`` + ``vendor/`` dump):
- ``system/build.prop`` / ``vendor/build.prop``: model, SDK levels,
  fingerprint, hardware, VNDK version
- ``vendor/etc/fstab.*``: filesystem per partition (ext4 / erofs / f2fs)
- ``system/etc/floating_feature.xml``: HFR refresh-rate defaults
- ``vendor/etc/vintf/manifest.xml``: FCM target-level + HAL versions
- ``vendor/etc/dvfs/`` (or ``system/etc/dvfs/``): SIOP policy filename
- ``vendor/etc/sensors/`` presence: sensor HAL hint

Output: JSON on stdout, plus ``--markdown`` for a human-readable table.
Nothing is downloaded, nothing is written except the requested output.

Usage:
    python3 auto_gen_facts.py <stock-tree-root> [--markdown facts.md]

Exit codes: 0 ok, 1 root missing / unreadable, 2 no facts found at all.
"""

import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET


def read_props(path):
    props = {}
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()
    except OSError:
        pass
    return props


def first_existing(root, relpaths):
    for rel in relpaths:
        p = os.path.join(root, rel)
        if os.path.isfile(p):
            return p
    return None


def fstab_filesystems(root):
    """{mount_point: filesystem} from every fstab.* under vendor/etc."""
    out = {}
    vend = os.path.join(root, "vendor", "etc")
    if not os.path.isdir(vend):
        return out
    for name in sorted(os.listdir(vend)):
        if not name.startswith("fstab"):
            continue
        with open(os.path.join(vend, name), "r", encoding="utf-8",
                  errors="replace") as f:
            for line in f:
                if not line.strip() or line.lstrip().startswith("#"):
                    continue
                parts = line.split()
                if len(parts) >= 3:
                    out[parts[1]] = parts[2]
    return out


def floating_feature(root):
    """HFR values from floating_feature.xml, if present."""
    path = first_existing(root, [
        "system/etc/floating_feature.xml",
        "system/system/etc/floating_feature.xml",
        "vendor/etc/floating_feature.xml",
    ])
    out = {}
    if not path:
        return out
    try:
        for line in open(path, "r", encoding="utf-8", errors="replace"):
            for key in ("HFR_DEFAULT_REFRESH_RATE", "HFR_MODE",
                        "HFR_SUPPORTED_REFRESH_RATE"):
                m = re.search(r"<SEC_FLOATING_FEATURE[^>]*%s[^>]*>([^<]*)<" % key, line)
                if m:
                    out[key] = m.group(1).strip()
    except OSError:
        pass
    return out


def vintf_manifest(root):
    """(target_level, {hal_name: [versions]}) from the vendor manifest."""
    path = first_existing(root, [
        "vendor/etc/vintf/manifest.xml",
        "vendor/manifest.xml",
    ])
    if not path:
        return None, {}
    try:
        tree = ET.parse(path)
    except ET.ParseError:
        return None, {}
    root_el = tree.getroot()
    target = root_el.get("target-level")
    hals = {}
    for hal in root_el.iter("hal"):
        name_el = hal.find("name")
        if name_el is None or not name_el.text:
            continue
        versions = [v.text.strip() for v in hal.findall("version")
                    if v.text and v.text.strip()]
        hals[name_el.text.strip()] = versions
    return target, hals


def siop_policy(root):
    """SIOP policy filename from the dvfs directory listing."""
    for rel in ("vendor/etc/dvfs", "system/etc/dvfs", "vendor/etc"):
        d = os.path.join(root, rel)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if name.startswith("siop") and name.endswith(".xml"):
                return name
    return None


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Derive device facts from a stock firmware tree.")
    ap.add_argument("root", help="stock firmware tree root "
                                "(contains system/ and vendor/)")
    ap.add_argument("--markdown", default=None,
                    help="also write a Markdown fact table to this file")
    args = ap.parse_args(argv)

    if not os.path.isdir(args.root):
        print("error: no such directory: %s" % args.root, file=sys.stderr)
        return 1

    sys_props = read_props(os.path.join(args.root, "system", "build.prop"))
    ven_props = read_props(os.path.join(args.root, "vendor", "build.prop"))
    props = dict(sys_props)
    props.update(ven_props)

    facts = {
        "model": props.get("ro.product.model"),
        "device": props.get("ro.product.device"),
        "hardware": props.get("ro.hardware") or props.get("ro.boot.hardware"),
        "sdk": props.get("ro.build.version.sdk"),
        "vendor_sdk": props.get("ro.vendor.build.version.sdk"),
        "vndk_version": props.get("ro.vndk.version"),
        "fingerprint": props.get("ro.build.fingerprint"),
        "security_patch": props.get("ro.build.version.security_patch"),
        "filesystems": fstab_filesystems(args.root),
        "floating_feature": floating_feature(args.root),
        "siop_policy": siop_policy(args.root),
    }
    target, hals = vintf_manifest(args.root)
    facts["fcm_target_level"] = target
    facts["hal_count"] = len(hals)
    facts["hals"] = hals

    if not any(v for k, v in facts.items()
               if k not in ("hals", "hal_count") and v):
        print("error: no facts found under %s" % args.root, file=sys.stderr)
        return 2

    print(json.dumps(facts, indent=2, sort_keys=True))
    if args.markdown:
        with open(args.markdown, "w", encoding="utf-8") as f:
            f.write("# Device facts (derived from stock firmware)\n\n")
            f.write("Generated by vendor/scripts/auto_gen_facts.py — "
                    "facts read from the firmware, not hand-written.\n\n")
            f.write("| Fact | Value |\n|---|---|\n")
            for key in ("model", "device", "hardware", "sdk", "vendor_sdk",
                        "vndk_version", "security_patch", "siop_policy",
                        "fcm_target_level", "hal_count"):
                f.write("| %s | %s |\n" % (key, facts.get(key) or "-"))
            f.write("\n## Filesystems (fstab)\n\n")
            for mount, fs in sorted(facts["filesystems"].items()):
                f.write("- `%s`: %s\n" % (mount, fs))
            if facts["floating_feature"]:
                f.write("\n## Floating feature (HFR)\n\n")
                for k, v in sorted(facts["floating_feature"].items()):
                    f.write("- `%s`: %s\n" % (k, v))
        print("markdown: %s" % args.markdown)
    return 0


if __name__ == "__main__":
    sys.exit(main())
