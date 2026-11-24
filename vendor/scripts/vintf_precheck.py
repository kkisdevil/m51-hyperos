#!/usr/bin/env python3
"""vintf_precheck.py — VINTF parser precheck (m51 HyperOS port).

Our own implementation of the method from Arnav3078/Hyper371-M51
``docs/VINTF.md`` (credited in vendor/README.md): before any device
test, parse the framework compatibility matrices and the vendor
manifest as XML and count mandatory FAIL / UNCHECKED — without running
Google's official ``check_vintf`` (which needs a device or a full
AOSP checkout).

What it checks, per matrix HAL entry:
- the HAL name must exist in the vendor manifest (any version), and
- the manifest version must satisfy the matrix requirement
  (``<version>1.5</version>`` means exactly 1.5; a matrix entry may
  list several versions, any one of which satisfies it).

An entry is FAIL when a mandatory HAL is missing or its version does
not satisfy the matrix. It is UNCHECKED when the versions cannot be
compared (e.g. a non-numeric version string) — the tool says so
instead of guessing. Optional matrix HALs (``optional="true"``) are
reported but never count as FAIL.

This is NOT a formal VTS check and must never be presented as one —
Hyper371's own doc says the same. It is a desk check that catches
manifest surgery mistakes (a sed that deleted a HAL, a version
bump that nothing implements) before the first boot.

Usage:
    python3 vintf_precheck.py --matrix compatibility_matrix.5.xml
        [--matrix compatibility_matrix.device.xml ...]
        --manifest vendor_manifest.xml [--manifest product_manifest.xml ...]
        [--report report.md]

Exit codes: 0 when mandatory FAIL == 0, 1 when any mandatory FAIL,
2 on bad input (missing file / unparsable XML).
"""

import argparse
import sys
import xml.etree.ElementTree as ET


def parse_version(text):
    """'1.5' -> (1, 5); returns None when the string is not numeric."""
    try:
        return tuple(int(p) for p in text.strip().split("."))
    except (ValueError, AttributeError):
        return None


def hal_entries(root, kind):
    """Yield (name, [versions], optional) for <hal> entries under root.

    ``kind`` is 'matrix' (framework compatibility matrix: <hal> has
    <name>, <version> children, optional="true" attribute) or
    'manifest' (vendor manifest: <hal> has <name>, <version> children,
    <interface> children; version may also sit on <fqname>).
    """
    for hal in root.iter("hal"):
        name_el = hal.find("name")
        if name_el is None or not name_el.text:
            continue
        name = name_el.text.strip()
        versions = []
        for v in hal.findall("version"):
            if v.text and v.text.strip():
                versions.append(v.text.strip())
        # Manifest HALs sometimes carry the version only in <fqname>,
        # e.g. android.hardware.camera.provider@2.6::ICameraProvider
        if not versions and kind == "manifest":
            for fq in hal.findall("fqname"):
                if fq.text and "@" in fq.text:
                    versions.append(fq.text.split("@", 1)[1].split("::")[0])
        optional = hal.get("optional", "false").lower() == "true"
        yield name, versions, optional


def check(matrix_files, manifest_files):
    """Return (fail, unchecked, rows) where rows are dicts for the report."""
    manifest = {}  # name -> set of version tuples (None if unparseable)
    for path in manifest_files:
        root = ET.parse(path).getroot()
        for name, versions, _opt in hal_entries(root, "manifest"):
            manifest.setdefault(name, set())
            for v in versions:
                manifest[name].add(parse_version(v))

    fail = 0
    unchecked = 0
    rows = []
    for path in matrix_files:
        root = ET.parse(path).getroot()
        for name, versions, optional in hal_entries(root, "matrix"):
            required = [parse_version(v) for v in versions]
            have = manifest.get(name)
            if not required or any(r is None for r in required):
                # The matrix version itself cannot be compared — say
                # UNCHECKED instead of guessing, even if the HAL is
                # also missing from the manifest.
                status = "UNCHECKED"
                unchecked += 1
            elif have is None:
                status = "FAIL" if not optional else "OPTIONAL-MISSING"
                if not optional:
                    fail += 1
            elif any(r in have for r in required):
                status = "OK"
            else:
                status = "FAIL" if not optional else "OPTIONAL-MISMATCH"
                if not optional:
                    fail += 1
            rows.append({
                "matrix": path,
                "hal": name,
                "required": ", ".join(versions) or "-",
                "have": ", ".join(
                    ".".join(str(p) for p in v) if v else "?"
                    for v in sorted(have, key=str)) if have is not None else "-",
                "optional": optional,
                "status": status,
            })
    return fail, unchecked, rows


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="VINTF parser precheck: framework matrices vs vendor manifest.")
    ap.add_argument("--matrix", action="append", required=True,
                    help="framework compatibility matrix XML (repeatable)")
    ap.add_argument("--manifest", action="append", required=True,
                    help="vendor/product manifest XML (repeatable)")
    ap.add_argument("--report", default=None,
                    help="also write a Markdown report to this file")
    args = ap.parse_args(argv)

    try:
        fail, unchecked, rows = check(args.matrix, args.manifest)
    except ET.ParseError as e:
        print("error: unparsable XML: %s" % e, file=sys.stderr)
        return 2
    except FileNotFoundError as e:
        print("error: %s" % e, file=sys.stderr)
        return 2

    print("checked %d matrix HAL entries against %d manifest file(s)"
          % (len(rows), len(args.manifest)))
    print("mandatory FAIL: %d   UNCHECKED: %d" % (fail, unchecked))
    for r in rows:
        if r["status"] != "OK":
            print("  %-4s %-55s required %s, have %s%s"
                  % (r["status"], r["hal"], r["required"], r["have"],
                     " (optional)" if r["optional"] else ""))
    if fail == 0 and unchecked == 0:
        print("precheck: PASS (0 mandatory FAIL, 0 UNCHECKED)")
    if args.report:
        with open(args.report, "w", encoding="utf-8") as f:
            f.write("# VINTF precheck report\n\n")
            f.write("Parser-based precheck (NOT official check_vintf, NOT "
                    "VTS certification). Mandatory FAIL: %d, UNCHECKED: %d.\n\n"
                    % (fail, unchecked))
            f.write("| HAL | Required | Have | Status |\n|---|---|---|---|\n")
            for r in rows:
                f.write("| %s | %s | %s | %s |\n"
                        % (r["hal"], r["required"], r["have"], r["status"]))
        print("report:   %s" % args.report)
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
