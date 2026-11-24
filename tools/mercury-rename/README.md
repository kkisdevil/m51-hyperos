# mercury-rename — AI auto-rename for decompiled vendor blobs

Ghidra decompiles a vendor blob into pseudo-C with auto-generated names
(`FUN_00101000`). Mercury 3 reads each function — code, strings,
callers, callees — and proposes a real name plus a one-line summary.
The names go back into Ghidra and into a readable C file that
clean-room rebuilds start from.

Built for the Galaxy M51 HyperOS port (see `docs/blob-audit.md`: 732 of
913 vendor files are binary-only). It does not recover the original
source — nothing can. It makes decompiled output **readable**, which is
what a rebuild needs.

## What it does and does not do

- DOES: decompile a `.so` with Ghidra headless, ask Mercury 3 to name
  each unnamed function, cache the answers, and write renamed C plus a
  Ghidra rename script.
- DOES NOT: recover original source, original names, comments, types, or
  macros. A proposed name is an AI guess — confidence is recorded per
  function, and anything below 0.5 keeps a `sub_<address>` placeholder
  marked NEEDS-REVIEW. Verify every name against the code before
  reusing it in a rebuild.
- Small HALs can be clean-room rebuilt from this output. Large stacks
  (CamX's 191 camera libs, the Adreno userspace, the modem) cannot be
  rebuilt this way — they get shims and targeted patches instead.

## Endpoint, model, key — read this first

Mercury 3 is called through the **Inception Labs API directly**
(user's explicit order, 2026-11-24: "Make it for Mercury 3 directly",
corrected 18:07 IST: Mercury must ALWAYS come from Inception Labs,
never Experimental Labs). This overrides the Luna-only testing rule
for THIS tool — that rule covers testing; the user explicitly chose
Mercury 3 from Inception here.

- Base URL: `api.inceptionlabs.ai/v1` (see [Inception API docs](https://docs.inceptionlabs.ai))
- Endpoint: `POST /v1/chat/completions` (OpenAI-compatible)
- Model: `mercury-3`
- Key: an **Inception Mercury key** (`MERCURY_API_KEY`). 7 such keys
  exist in the Oracle1 panel vault, verified working 2026-11-18.
  There is NO Experimental Labs involvement — never point this tool
  at the Experimental Labs API.
- The key is read from the environment at runtime only. It is never
  hardcoded, never logged, never written to a file, and never appears
  in chat. Copy `.env.example` to `.env` and fill it in — `.env` is
  gitignored and must never be committed.

IMPORTANT — Mercury sunset: Inception's own docs state the Mercury API
is winding down and remains fully available only through
**December 28, 2026**; after that date there is no access to the
service. That sunset DOES govern this tool (it calls Inception
directly), so use the remaining window and keep the cache warm — every
rename cached before the sunset stays usable forever. The base URL and
model are config anyway, so the pipeline can point at another
OpenAI-compatible endpoint with one setting change after the sunset.

## Setup

```sh
# 1. Ghidra (headless only, ~570 MB download, SHA-256 verified)
bash setup-ghidra.sh
#    Ghidra 12.2, official release, published SHA-256
#    2c2cd776db3c1f6a097ba418922378ac3649cadd5e844a6f5f088ae628a7be67
#    Requires a 64-bit JDK 25 (sudo apt-get install -y openjdk-25-jdk).

# 2. Key (see above)
cp .env.example .env   # fill in MERCURY_API_KEY, never commit .env
export MERCURY_API_KEY="..."   # or: set -a; source .env; set +a
```

No pip installs are needed: the Python code uses the standard library
only (`urllib`, `json`, `sqlite3`).

## Usage — one HAL, end to end

```sh
GHIDRA=tools/mercury-rename/ghidra/ghidra_12.2_PUBLIC
PROJ=/tmp/ghidra-proj

# 1. Decompile: dump per-function JSON
"$GHIDRA/support/analyzeHeadless" "$PROJ" rename \
    -import vendor/lib64/hw/lights.sm6150.so \
    -postScript DumpFunctions lights.json \
    -scriptPath tools/mercury-rename/ghidra_scripts \
    -deleteProject
#    Add -processor AARCH64 if the language is not auto-detected.

# 2. Rename with Mercury 3 (one API call per unnamed function)
python3 rename.py lights.json --out lights.renamed.json
#    --max-functions N   to cap a run; --dry-run to preview prompts
#    with zero API calls; --rename-all to also rename named functions.

# 3. Apply: renamed C + Ghidra rename script
python3 apply_names.py lights.json lights.renamed.json \
    --out-c lights.renamed.c --out-script ApplyNames.py
#    To apply inside Ghidra instead:
#    analyzeHeadless "$PROJ" rename -import <file.so> \
#        -postScript ApplyNames lights.renamed.json \
#        -scriptPath tools/mercury-rename/ghidra_scripts -deleteProject
```

Re-running step 2 over the same dump makes **zero API calls**: results
are cached in `cache/rename_cache.db`, keyed by SHA-256 of (model +
prompt version + function content). Changing the model or the prompt
invalidates the cache automatically.

## Cost and scale

- One API call per unnamed function (default `temperature 0`,
  `max_completion_tokens 1024`, `reasoning_effort low` — Mercury 3's
  own default, per Inception's API spec; naming does not need deep
  reasoning).
- Work **one HAL at a time** with `--max-functions` as a brake. A
  whole vendor tree at once would be thousands of calls; the cache
  makes re-runs free, but the first pass still costs one call per
  function.
- Rate limits (429) and 5xx are retried with exponential backoff
  (honouring `Retry-After`). 401 (bad key) and 402 (out of credits)
  fail immediately — retrying cannot help.

## Live test plan (the one manual step)

No key exists in this sandbox and none may be fetched from the vault
here, so no live Mercury call was made during development. The live
test runs in the **main chat**, which holds the vault Mercury key:

1. The tool + a small test HAL (the lights HAL — see
   `docs/re-lights.md`, or any small `.so` from the audit) go to the
   main chat.
2. There, with `MERCURY_API_KEY` set from the vault (an Inception
   Mercury key — never the Experimental Labs key):
   ```sh
   python3 rename.py lights.json --out lights.renamed.json --max-functions 5
   ```
   Expect: 5 API calls, 5 renames with summaries, then a second run
   over the same dump making 0 calls (cache hit).
3. If the endpoint rejects the call, the client prints the HTTP status
   and the server's message — report that verbatim; do not retry with
   a different key.

Validated WITHOUT a key (this sandbox): Ghidra 12.2 headless
decompiles a real `.so` — `liblow_light_hdr.so` (AArch64 vendor blob
from the pinned a71-common tree, stripped): 1100 functions,
1100 decompiled, 944 unnamed; the full driver → cache → applier flow
runs against a local mock Mercury server (`tests/run_mock_e2e.sh`),
and the second run is a pure cache hit with zero mock calls. See
"Validation" below.

## Files

| File | What it is |
|---|---|
| `setup-ghidra.sh` | Download + SHA-256 verify + extract Ghidra 12.2, check `analyzeHeadless` |
| `ghidra_scripts/DumpFunctions.java` | Headless Ghidra script: decompile, dump per-function JSON |
| `mercury_client.py` | Mercury 3 client (stdlib `urllib`, retries, backoff) |
| `rename.py` | Driver: prompts, cache, CLI (`--dry-run`, `--max-functions`) |
| `apply_names.py` | Writes `<binary>.renamed.c` + Ghidra `ApplyNames.py` |
| `tests/mock_mercury.py` | Local stub of the chat-completions API (tests only) |
| `tests/sample_dump.json` | 3-function sample dump for the e2e test |
| `tests/run_mock_e2e.sh` | End-to-end test against the mock (no key needed) |
| `.env.example` | Key + endpoint config template (never commit a filled copy) |

## Validation (run before reporting the tool done)

```sh
bash -n setup-ghidra.sh tests/run_mock_e2e.sh
python3 -m py_compile mercury_client.py rename.py apply_names.py tests/mock_mercury.py
bash tests/run_mock_e2e.sh        # mock server: rename + cache hit + applier
bash setup-ghidra.sh --check      # analyzeHeadless present and runnable
# Ghidra on a real .so (see Validation notes in the repo):
#   analyzeHeadless ... -postScript DumpFunctions <out.json> ...
#   then rename.py --dry-run against the dump.
```

## Credits

- [Ghidra](https://github.com/NationalSecurityAgency/ghidra) (Apache-2.0)
  — the decompiler engine; our code is only the AI layer on top.
- Mercury 3 — Inception Labs' model, served here through the
  Experimental Labs API.
- Galaxy M51 vendor trees: a71-devs (device + vendor, lineage-22.2);
  see `trees/manifest.json` for pins.
- License: GPL-3.0 (same as the repo). See `LICENSE`.
