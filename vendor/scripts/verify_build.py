#!/usr/bin/env python3
"""verify_build.py — build verification record (m51 HyperOS port).

Our own implementation of the verification discipline from
Arnav3078/Hyper371-M51 ``docs/VERIFICATION.md`` +
``TEST_REPORT_TEMPLATE.md`` (credited in vendor/README.md), which is
the same discipline skill §10.1 demands for every build:

- SHA-256 for every image/file in the build output directory
- ``unzip -t`` on every .zip (a corrupt flashable zip must fail here,
  not on the phone)
- ``fsck.erofs --xattrs --extract`` on every .img when erofs-utils
  is available (reported as SKIPPED when it is not — never faked)
- optional ``--expected manifest.json``: compare computed hashes
  against a published hash list (``{"file": "<sha256>", ...}``)

Writes ``VERIFICATION.md`` in the output directory (or ``--report``)
and prints the summary. Exit 0 when every check that could run
passed and every expected hash matched; 1 otherwise.

Usage:
    python3 verify_build.py <build-dir> [--expected hashes.json]
                        [--report VERIFICATION.md]
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

CHUNK = 1024 * 1024


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(CHUNK)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def check_zip(path):
    """Return (ok, detail) for `unzip -t`."""
    unzip = shutil.which("unzip")
    if not unzip:
        return None, "unzip not installed — SKIPPED"
    r = subprocess.run([unzip, "-t", path], capture_output=True, text=True)
    if r.returncode == 0:
        return True, "unzip -t ok"
    tail = (r.stdout + r.stderr).strip().splitlines()[-1:] or ["unzip failed"]
    return False, tail[0]


def check_erofs(path):
    """Return (ok, detail) for `fsck.erofs --xattrs --extract`."""
    fsck = shutil.which("fsck.erofs")
    if not fsck:
        return None, "fsck.erofs not installed — SKIPPED"
    with open(os.devnull, "wb") as devnull:
        r = subprocess.run([fsck, "--xattrs", "--extract", path],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, timeout=600)
    if r.returncode == 0:
        return True, "fsck.erofs --xattrs ok"
    tail = r.stdout.strip().splitlines()[-1:] or ["fsck.erofs failed"]
    return False, tail[0]


def is_erofs(path):
    """EROFS superblock magic 0xE0F5E1E2 at offset 1024."""
    try:
        with open(path, "rb") as f:
            f.seek(1024)
            return f.read(4) == b"\xe2\xe1\xf5\xe0"
    except OSError:
        return False


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Write a verification record for a build output directory.")
    ap.add_argument("build_dir", help="directory holding the built images/zips")
    ap.add_argument("--expected", default=None,
                    help="JSON {filename: sha256} to compare against")
    ap.add_argument("--report", default=None,
                    help="report path (default: <build_dir>/VERIFICATION.md)")
    args = ap.parse_args(argv)

    expected = {}
    if args.expected:
        with open(args.expected, "r", encoding="utf-8") as f:
            expected = json.load(f)

    files = sorted(f for f in os.listdir(args.build_dir)
                   if os.path.isfile(os.path.join(args.build_dir, f))
                   and f != os.path.basename(args.report or "VERIFICATION.md"))
    if not files:
        print("error: no files in %s" % args.build_dir, file=sys.stderr)
        return 1

    rows = []
    failures = 0
    for name in files:
        path = os.path.join(args.build_dir, name)
        digest = sha256_of(path)
        size = os.path.getsize(path)
        checks = []
        if name.endswith(".zip"):
            ok, detail = check_zip(path)
            checks.append(("unzip -t", ok, detail))
        if name.endswith(".img") and is_erofs(path):
            ok, detail = check_erofs(path)
            checks.append(("fsck.erofs", ok, detail))
        exp = expected.get(name)
        if exp is not None:
            match = digest == exp.lower()
            checks.append(("expected sha256", match,
                           "matches published hash" if match
                           else "MISMATCH: expected %s" % exp))
        for _label, ok, _detail in checks:
            if ok is False:
                failures += 1
        rows.append((name, size, digest, checks))

    for name, size, digest, checks in rows:
        print("%s  %12d bytes  %s" % (digest[:16], size, name))
        for label, ok, detail in checks:
            state = "ok" if ok is True else ("SKIPPED" if ok is None else "FAIL")
            print("    [%s] %s: %s" % (state, label, detail))

    report = args.report or os.path.join(args.build_dir, "VERIFICATION.md")
    with open(report, "w", encoding="utf-8") as f:
        f.write("# Build verification record\n\n")
        f.write("SHA-256 per file, zip integrity, EROFS xattr check where "
                "the tool exists. A SKIPPED check is reported, never faked.\n\n")
        f.write("| File | Size (bytes) | SHA-256 | Checks |\n")
        f.write("|---|---|---|---|\n")
        for name, size, digest, checks in rows:
            summary = "; ".join(
                "%s: %s" % (label, "ok" if ok is True else
                            ("SKIPPED" if ok is None else "FAIL — " + detail))
                for label, ok, detail in checks) or "-"
            f.write("| %s | %d | %s | %s |\n" % (name, size, digest, summary))
    print("report:   %s" % report)
    print("failures: %d" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
