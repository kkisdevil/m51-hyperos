# Blob refresh — re-extract vendor blobs from stock firmware DXJ2

Date: 2026-11-24. Phase 0 execution step (tree-takeover.md §5).
Status: **STOPPED at step 2 — no firmware downloaded, no diff produced.**
The stop is deliberate: Samsung's own firmware server does not report
DXJ2 as the latest for any region checked, so downloading would have
fetched the wrong firmware. The decision on what to download instead
belongs to the parent (see §6).

Repo: https://github.com/kkisdevil/m51-hyperos, GPL-3.0.
Local work dir: `~/workspace/m51-hyperos/blob-refresh/` (gitignored —
firmware, venv, and scratch live there; never committed).

## 1. What was supposed to happen

Per tree-takeover.md §5: download stock **M515FXXU6DXJ2** (latest
stock, Oct 2024), run the trees' own `extract-files.py` against it,
diff the fresh blob set against the frozen 913 (180 m51 + 733
a71-common, tree-takeover.md §2.2), record the diff here, and update
`lineage_m51.mk`'s build fingerprint (DXE3 → DXJ2) and
`VENDOR_SECURITY_PATCH` (2024-05-01 → DXJ2 level). Blobs that
disappear must not be deleted without checking whether a HAL still
loads them.

## 2. Method + tools (what was actually set up)

- Work dir `blob-refresh/`, added to `.gitignore` (`blob-refresh/`).
- Disk: `/home/hatch` — 150 GB volume, **141 GB free** at start.
  A full firmware (~7–8 GB) plus extraction scratch fits.
- Python 3.12.3 (system). A venv was created at
  `blob-refresh/venv/` to avoid touching system packages.
- **samloader: NOT on PyPI any more.** `pip install samloader`
  fails — `pypi.org/pypi/samloader/json` returns `{"message":
  "Not Found"}` and the simple index 404s (checked 2026-11-24).
  Fallback used: source tarball from GitHub codeload
  (`ananjaser1211/samloader`, branch `master`,
  `blob-refresh/samloader.tar.gz`, 45,714 bytes), extracted to
  `blob-refresh/samloader-master/`, dependencies installed from its
  own `requirements.txt` into the venv
  (`pycryptodomex==3.20.0`, `Requests==2.31.0`, `tqdm==4.66.2`).
  `python -m samloader` from source imports and runs. No git clone
  was used anywhere in this step.
- `lz4` (Python package) installed into the venv — OK. The `lz4`
  CLI is not installed; the Python module covers `.lz4`
  decompression.
- `simg2img` / `lpunpack`: **not installed, not reached.** The
  step that needs them (step 3, unpacking `super.img`) was never
  started. Plan if the refresh resumes: pure-Python sparse-image
  parsing + LP-metadata parsing, or a prebuilt `lpunpack` binary;
  `debugfs` / `dumpe2fs` are present (`/usr/sbin/debugfs`) for
  reading the extracted ext4 vendor image without mounting.
- Network: PyPI and `raw.githubusercontent.com` both reachable
  (HTTP 200).

## 3. Firmware identity — what Samsung's server actually says

`samloader checkupdate` (FUS server, no IMEI supplied — samloader's
default), run 2026-11-24 ~10:50 IST. Format is
`PDA/CSC/CP/build`:

| Region | checkupdate result (latest per FUS) | Note |
|---|---|---|
| **INS** (India, user's region) | `M515FXXS6DXE3/M515FODM6DXE3/M515FXXS6DXE1/M515FXXS6DXE3` | Re-run twice, same answer |
| XSG | `M515FXXS6DXE3/M515FOJM6DXE1/M515FXXS6DXE1/M515FXXS6DXE3` | Same PDA, different CSC |
| BTU | `M515FXXS6DXE3/M515FOXM6DXE1/M515FXXS6DXE1/M515FXXS6DXE3` | Same PDA |
| SER | `M515FXXS6DXE3/M515FOXM6DXE1/M515FXXS6DXE1/M515FXXS6DXE3` | Same PDA |
| ZTO | `M515FXXS6DXE4/M515FOWO6DXE4/M515FXXS6DXE4/M515FXXS6DXE4` | One letter newer than DXE3 |
| XEU | `Error 403: Model or region not found (403) \| Or TAC is not for SM-M515F` | Not a valid region for this model |

**No region checked reports DXJ2 (or DXJ1).** The task's stop
condition is met: checkupdate says a different latest version, so
nothing was downloaded.

## 4. DXJ1 / DXJ2 do exist — just not where FUS points this query

Web evidence (checked the same day, not from FUS):

- **SamFrew lists `M515FXXU6DXJ1` for INS (India)** — PDA
  `M515FXXU6DXJ1`, CSC `M515FODM6DXJ1`, modem `M515FXXU6DXJ1`,
  build date **Oct 3, 2024**, upload Oct 15, 2024, 7.1 GB,
  One UI 4.1 / Android 12, **security patch May 1, 2024**,
  changelist **23974102**, kernel
  `4.14.190-23974023-abM515FXXU6DXJ1`, bootloader 6.
  (samfrew.com/download/Galaxy__M51__/6xua/INS/M515FXXU6DXJ1/M515FODM6DXJ1)
- **samfirm.shop** states "A newer build for SM-M515F is available:
  **M515FXXU6DXJ2**" (on the page for the old M515FXXU2CUB7 build).

Two things follow:

1. **The FUS answer depends on the IMEI/TAC.** samloader's
   checkupdate without a real device IMEI returns DXE3 for INS
   while a firmware mirror lists DXJ1 for the same region. The
   FUS server keys the "latest" off the device's IMEI type
   allocation code; a dummy/default IMEI gets a stale track.
   Do not treat a no-IMEI checkupdate as the authoritative
   latest — cross-check against a mirror first.
2. **DXJ1/DXJ2 are probably a near-no-op for the blobs.**
   DXJ1 still carries **security patch 2024-05-01** and
   **changelist 23974102** — the same patch level and the same
   source changelist as the DXE3-era builds. A newer build string
   does not mean newer vendor blobs. If the refresh is done from
   DXJ1/DXJ2, expect the diff against the frozen 913 to be small
   or empty, and expect **no** `VENDOR_SECURITY_PATCH` change
   (it would stay 2024-05-01). The only certain update would be
   the build fingerprint string itself (DXE3 → DXJ1/DXJ2).

## 5. Diff — not produced (blocked)

- Changed / added / disappeared blobs: **unknown — no firmware
  was downloaded, so no fresh blob set exists to diff.**
- Fingerprint update (DXE3 → DXJ2): **not applied** — the target
  firmware was not obtained, and the evidence in §4 suggests the
  real candidate is DXJ1 for INS, not DXJ2.
- `VENDOR_SECURITY_PATCH` update (2024-05-01 → DXJ2 level):
  **not applied** — and §4 suggests it would stay 2024-05-01
  even on DXJ1/DXJ2.
- No forked vendor repo was modified. Nothing was uploaded.

## 6. What remains open — decision needed

**DECISION (parent, 2026-11-24 ~10:52 IST): option (c) — accept the
frozen blobs as the base.** Rationale: DXJ1 carries the same security
patch (2024-05-01) and changelist (23974102) as the DXE3-era builds,
so the vendor blobs are almost certainly identical — a 7.1 GB mirror
download + extraction for a likely-zero diff is not worth it, and FUS
says DXE3 is the latest for INS (the user's region) anyway. The
frozen 913 stay as the port's vendor base. DXJ2's fingerprint bump
(DXE3 → DXJ2) is a one-line change to do later, once DXJ2's CSC is
identified — it does not block any port work. If a real vendor
difference ever shows up (a HAL failing on a frozen blob), revisit
option (a) then.

1. **Which firmware is the refresh target?** Options:
   a. **DXJ1 for INS** via a mirror (SamFrew lists it, 7.1 GB) —
      matches the user's region and phone; needs a mirror
      download (not FUS/samloader), and the mirror's checksum
      verified before use.
   b. **DXJ2** — named by samfirm.shop as the newer build, but no
      region for it is known yet; find which CSC shipped DXJ2
      before downloading.
   c. **Accept DXE3** — FUS says it is the latest for INS without
      a device IMEI, and the frozen blobs are already DXE3-era;
      a DXE3 refresh would likely diff to zero and only prove
      the frozen set is current.
2. **IMEI-accurate FUS query?** Supplying the physical m51's
   IMEI to samloader would return the true FUS latest for that
   device. That needs the IMEI from the user and was not asked
   for in this step.
3. **If the refresh resumes:** step 3 (AP tar → `super.img.lz4`
   → decompress → LP-unpack → vendor image), step 4 (fetch
   `extract-files.py` + `proprietary-files.txt` + extract-utils
   from the kkisdevil forks via raw.githubusercontent.com,
   branch `lineage-22.2` — no clone), step 5 (diff vs the frozen
   913; flag disappearing blobs for a HAL-load check, do not
   delete on assumption), step 6 (fingerprint + patch-level
   updates in the forked trees).
4. **Tooling gap to close on resume:** `simg2img`/`lpunpack`
   are absent — decide between pure-Python sparse + LP parsing
   (no new binaries) and a prebuilt `lpunpack` before step 3.

## 7. Sources

- tree-takeover.md §5 (procedure) and §2.2 (frozen 913:
  180 m51 + 733 a71-common).
- `samloader checkupdate` output, FUS server, 2026-11-24 ~10:50 IST
  (6 regions, INS re-run twice).
- SamFrew SM-M515F INS DXJ1 page; samfirm.shop M515FXXU2CUB7
  page ("newer build … M515FXXU6DXJ2").
- samloader source: `ananjaser1211/samloader` master tarball;
  PyPI `samloader` 404 (checked 2026-11-24).
