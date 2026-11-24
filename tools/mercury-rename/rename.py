#!/usr/bin/env python3
"""rename.py — AI auto-rename driver for mercury-rename.

Reads the per-function JSON produced by DumpFunctions.java, sends each
unnamed function (pseudo-C + context) to Mercury 3, and writes a
renamed JSON with a proposed name + one-line summary + confidence per
function.

Usage:
  python3 rename.py <dump.json> --out <renamed.json> [options]

Options:
  --cache PATH        SQLite cache (default: cache/rename_cache.db)
  --max-functions N   rename at most N functions (default: all)
  --rename-all        also rename functions that already have a real
                      name (default: only FUN_/LAB_/thunk-style names)
  --dry-run           build the prompts and print the first one; make
                      zero API calls and write nothing
  --base-url URL      Mercury base URL (default: env MERCURY_BASE_URL
                      or https://api.inceptionlabs.ai/v1)
  --model NAME        model id (default: env MERCURY_MODEL or mercury-3)
  --no-cache          ignore the cache (still writes to it)

The API key comes ONLY from the environment (MERCURY_API_KEY) — there
is no command-line flag for it, so it can never leak into shell
history or a process listing.

Cache: keyed by SHA-256 of (model + prompt version + function content).
A second run over the same dump makes zero API calls. Low-confidence
results (< 0.5) are kept as sub_<address> with needs_review=true so a
bad guess never becomes a misleading name.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mercury_client import MercuryClient, MercuryError  # noqa: E402

PROMPT_VERSION = "v1"
MAX_DECOMPILED_CHARS = 6000
LOW_CONFIDENCE = 0.5
NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
UNNAMED_RE = re.compile(r"^(FUN_|LAB_|thunk_|DAT_|PTR_|SUB_)[0-9a-fA-F_]+$")

SYSTEM_PROMPT = """You are a reverse-engineering assistant. You are given \
the Ghidra decompiled C of one function from an Android HAL shared \
library (.so) on an ARM64 Samsung phone, plus the strings it references \
and the functions that call it / it calls.

Propose a concise, meaningful snake_case C function name that says what \
the function DOES, a one-line summary, and your confidence (0.0-1.0).

Rules:
- The name must be a valid C identifier, snake_case, at most 60 \
characters. No generic names like function1, do_stuff, helper, or process.
- Base the name on what the code actually does (syscalls, sysfs paths, \
ioctls, string constants, called functions), not on a guess about the \
library.
- If you cannot tell what it does, return name null and a low \
confidence; do not invent a specific-sounding name.
- Reply with ONLY a JSON object, no other text:
  {"name": "<snake_case name or null>", "summary": "<one line>", \
"confidence": <0.0-1.0>}"""


def is_unnamed(name):
    """True when Ghidra gave the function an auto-generated name."""
    if not name:
        return True
    if UNNAMED_RE.match(name):
        return True
    # Bare hex-ish names Ghidra sometimes emits.
    return bool(re.match(r"^[0-9a-fA-F]{4,}$", name))


def sanitize_name(name, address):
    """Force a model proposal into a safe C identifier, or None."""
    if not name:
        return None
    name = name.strip().lower().replace("-", "_").replace(" ", "_")
    name = re.sub(r"[^a-z0-9_]", "_", name)
    name = re.sub(r"_+", "_", name).strip("_")
    if not name:
        return None
    if name[0].isdigit():
        name = "fn_" + name
    name = name[:60].rstrip("_")
    if not NAME_RE.match(name):
        return None
    return name


def content_hash(model, function):
    """Stable cache key: model + prompt version + function content."""
    material = "\n".join([
        model,
        PROMPT_VERSION,
        function.get("address", ""),
        function.get("name", ""),
        function.get("signature", ""),
        function.get("decompiled_c") or "",
        json.dumps(function.get("strings", []), sort_keys=True),
        json.dumps(function.get("callers", []), sort_keys=True),
        json.dumps(function.get("callees", []), sort_keys=True),
    ])
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def build_user_message(binary, function):
    """The per-function prompt: context first, code second."""
    code = function.get("decompiled_c") or ""
    truncated = len(code) > MAX_DECOMPILED_CHARS
    if truncated:
        code = code[:MAX_DECOMPILED_CHARS]
    lines = [
        "Binary: %s" % binary,
        "Function: %s at %s" % (function.get("name"), function.get("address")),
        "Signature: %s" % function.get("signature", ""),
        "Strings referenced: %s"
        % (", ".join(function.get("strings", [])[:20]) or "(none)"),
        "Called from (addresses): %s"
        % (", ".join(function.get("callers", [])[:20]) or "(none)"),
        "Calls (addresses): %s"
        % (", ".join(function.get("callees", [])[:20]) or "(none)"),
        "",
        "Decompiled C%s:" % (" (truncated to %d chars)" % MAX_DECOMPILED_CHARS
                             if truncated else ""),
        code,
    ]
    return "\n".join(lines)


def extract_json(text):
    """Parse the model's reply: strict JSON, else first {...} block."""
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        try:
            return json.loads(text[start:end + 1])
        except json.JSONDecodeError:
            return None
    return None


class RenameCache:
    """SQLite cache: one row per (model, prompt, function content)."""

    def __init__(self, path):
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        self.conn = sqlite3.connect(path)
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS renames ("
            "  content_hash TEXT PRIMARY KEY,"
            "  model TEXT NOT NULL,"
            "  address TEXT NOT NULL,"
            "  old_name TEXT NOT NULL,"
            "  new_name TEXT,"
            "  summary TEXT,"
            "  confidence REAL,"
            "  needs_review INTEGER,"
            "  created_at TEXT"
            ")")
        self.conn.commit()

    def get(self, content_hash):
        row = self.conn.execute(
            "SELECT new_name, summary, confidence, needs_review"
            " FROM renames WHERE content_hash = ?",
            (content_hash,)).fetchone()
        if not row:
            return None
        return {"new_name": row[0], "summary": row[1],
                "confidence": row[2], "needs_review": bool(row[3])}

    def put(self, content_hash, model, address, old_name, result):
        self.conn.execute(
            "INSERT OR REPLACE INTO renames"
            " (content_hash, model, address, old_name, new_name, summary,"
            "  confidence, needs_review, created_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (content_hash, model, address, old_name,
             result["new_name"], result["summary"], result["confidence"],
             1 if result["needs_review"] else 0,
             datetime.now(timezone.utc).isoformat()))
        self.conn.commit()

    def close(self):
        self.conn.close()


def rename_one(client, binary, function, used_names):
    """One Mercury call for one function. Returns the rename dict."""
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user",
         "content": build_user_message(binary, function)},
    ]
    reply = client.chat(messages)
    parsed = extract_json(reply)
    if not parsed:
        return {"new_name": None, "summary": "unparseable model reply",
                "confidence": 0.0, "needs_review": True}
    try:
        confidence = float(parsed.get("confidence", 0.0))
    except (TypeError, ValueError):
        confidence = 0.0
    confidence = max(0.0, min(1.0, confidence))
    name = sanitize_name(parsed.get("name"), function["address"])
    if name is None or confidence < LOW_CONFIDENCE:
        return {"new_name": None,
                "summary": parsed.get("summary") or "uncertain",
                "confidence": confidence, "needs_review": True}
    # Never hand two functions the same name.
    base = name
    suffix = 2
    while name in used_names:
        name = "%s_%d" % (base, suffix)
        suffix += 1
    return {"new_name": name,
            "summary": parsed.get("summary") or "",
            "confidence": confidence, "needs_review": False}


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Auto-rename Ghidra-decompiled functions with Mercury 3.")
    parser.add_argument("dump", help="dump JSON from DumpFunctions.java")
    parser.add_argument("--out", required=True, help="renamed JSON output")
    parser.add_argument("--cache", default="cache/rename_cache.db",
                        help="SQLite cache path")
    parser.add_argument("--max-functions", type=int, default=None)
    parser.add_argument("--rename-all", action="store_true",
                        help="also rename functions that already have a name")
    parser.add_argument("--dry-run", action="store_true",
                        help="build prompts, print the first, no API calls")
    parser.add_argument("--base-url", default=None)
    parser.add_argument("--model", default=None)
    parser.add_argument("--no-cache", action="store_true")
    args = parser.parse_args(argv)

    with open(args.dump, "r", encoding="utf-8") as fh:
        dump = json.load(fh)
    binary = dump.get("binary", "?")
    functions = dump.get("functions", [])

    targets = []
    for function in functions:
        if not function.get("decompile_ok"):
            continue
        if not args.rename_all and not is_unnamed(function.get("name", "")):
            continue
        targets.append(function)
        if args.max_functions and len(targets) >= args.max_functions:
            break

    if args.dry_run:
        print("dry-run: %d functions would be renamed (of %d in dump)"
              % (len(targets), len(functions)))
        if targets:
            print("--- first prompt (user message) ---")
            print(build_user_message(binary, targets[0]))
            print("--- end prompt ---")
        print("dry-run: zero API calls made, nothing written")
        return 0

    client = MercuryClient(base_url=args.base_url, model=args.model)
    cache = None if args.no_cache else RenameCache(args.cache)
    used_names = {f.get("name") for f in functions if f.get("name")}

    renames = []
    stats = {"total": len(functions), "targets": len(targets),
             "renamed": 0, "cached": 0, "api_calls": 0,
             "needs_review": 0, "skipped_named": len(functions) - len(targets)}
    try:
        for function in targets:
            old_name = function["name"]
            address = function["address"]
            key = content_hash(client.model, function)
            cached = cache.get(key) if cache else None
            if cached is not None:
                result = cached
                stats["cached"] += 1
            else:
                try:
                    result = rename_one(client, binary, function, used_names)
                except MercuryError as exc:
                    print("ERROR: %s" % exc, file=sys.stderr)
                    return 1
                stats["api_calls"] += 1
                if cache:
                    cache.put(key, client.model, address, old_name, result)
            if result["new_name"]:
                used_names.add(result["new_name"])
                stats["renamed"] += 1
            if result["needs_review"]:
                stats["needs_review"] += 1
            renames.append({
                "address": address,
                "old_name": old_name,
                "new_name": result["new_name"]
                            or ("sub_%s" % address.replace("0x", "")),
                "summary": result["summary"],
                "confidence": result["confidence"],
                "cached": cached is not None,
                "needs_review": result["needs_review"],
            })
            print("%s %s -> %s (conf %.2f%s)" % (
                address, old_name,
                renames[-1]["new_name"], result["confidence"],
                ", cached" if cached is not None else ""))
    finally:
        if cache:
            cache.close()

    output = {"binary": binary, "model": client.model,
              "prompt_version": PROMPT_VERSION, "renames": renames,
              "stats": stats}
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(output, fh, indent=2)
    print("wrote %s: %d renamed, %d cached, %d API calls, "
          "%d need review" % (args.out, stats["renamed"], stats["cached"],
                              stats["api_calls"], stats["needs_review"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
