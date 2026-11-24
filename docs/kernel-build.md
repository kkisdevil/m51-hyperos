# First kernel build — Galaxy M51 (SM-M515F)

Date: 2026-11-24. Repo: https://github.com/kkisdevil/m51-hyperos, GPL-3.0
(kernel tree and defconfig stay GPL-2.0, as the kernel is).

Companion files: [kernel-defconfig-plan.md](kernel-defconfig-plan.md)
(the defconfig resolution + the 8 gates this build runs) and
`.github/workflows/build-kernel.yml` (the workflow). Skill:
`m51-rom-builder` §6.

Status: **run #1 FAILED 2026-11-24 11:24 IST (run 45336076805,
4m 1s) — "Install build dependencies": `E: Unable to locate
package libtinfo5` (exit 100). `libtinfo5` is not in the noble
repos at all; the workflow now fetches the current jammy .deb
from the Ubuntu security pool (fix below, §1 + §5). No kernel
has been built yet — run #2 is dispatched on the fix.**

## 1. Toolchain pin — proton-clang

**Pinned:** `kdrag0n/proton-clang`, branch `master`, commit
`9fb011b183fe7e69b04b873ef6533b4b077e3c5e` ("Update to 20210522
build", 2021-05-22). Clang 13.0.0 (the workflow's version gate
prints the exact `clang --version` string at build time).

Why this one:

- **It is frozen.** Last push 2021-05-22 (verified via the GitHub
  API 2026-11-24); the README's "continuously updating" line is
  stale. A frozen toolchain is a deterministic pin — the same
  commit builds the same way next month.
- **It needs no second toolchain.** `bin/` contains `clang`,
  `ld.lld`, `llvm-ar`, and the GNU binutils with the
  `aarch64-linux-gnu-` prefix (`as`, `ld`, `ld.bfd`, `objcopy`,
  …) — verified by listing `bin/` via the API (142 entries). The
  README states it explicitly: "users do not need to download
  separate GCC toolchains to build the Linux kernel." There is NO
  `aarch64-linux-gnu-gcc` in it — the build is full-Clang, not the
  GCC-4.9 + `REAL_CC` hybrid the old `build_kernel.sh` expected.
- **The recipe is documented by the project itself** (README):
  `CC=clang`, `CROSS_COMPILE=aarch64-linux-gnu-`,
  `CLANG_TRIPLE=aarch64-linux-gnu-`, toolchain `bin/` on `PATH`.
  The workflow follows it exactly.
- **It is the de-facto standard for 4.14 Samsung/QTI kernels**
  in the custom-ROM community, and Clang 13 is inside the range
  known to build 4.14 (ClangBuiltLinux supports 4.14 with Clang
  13; the 4.14 Makefile sets `CONFIG_CC_IS_CLANG` itself).

Deviation from the plan, recorded: `kernel-defconfig-plan.md` §5
assumed GCC 4.9 (`CROSS_COMPILE=<gcc-4.9-prefix>`) + Clang as
`REAL_CC`. That combination requires fetching two toolchains
(AOSP GCC 4.9 + a Clang) and matches a script that never worked.
proton-clang replaces both halves with one clone. If the
full-Clang build fails on a 4.14-isms error (inline asm, a
`-Werror` the old GCC tolerated), the fallback is the plan's
original combination — see §5 below — not a different Clang.

**Host-compat note (corrected 2026-11-24 after run #1 failed):**
proton-clang was built on Ubuntu 18.04 (glibc 2.27) and its `clang`
links `libtinfo.so.5`, which ubuntu-24.04 does not ship — and
`libtinfo5` is **not in the noble repos at all**: run #1 died in the
"Install build dependencies" step with `E: Unable to locate package
libtinfo5` (exit 100). The earlier claim in this doc that libtinfo5
"exists for noble (packages.ubuntu.com, HTTP 200)" was wrong —
`packages.ubuntu.com/noble/libtinfo5` is an error page (the bare
HTTP 200 was the error page, not a package page), and multiple
independent sources confirm noble dropped ncurses 5. The workflow
therefore installs the other build deps via apt and fetches the
current jammy `libtinfo5` .deb from the Ubuntu security pool
(`security.ubuntu.com/ubuntu/pool/universe/n/ncurses/`, filename
resolved from the pool listing so a superseded security revision
cannot 404 the build — the `6.3-2ubuntu0.1` file cited in blog
posts is already gone; current is `6.3-2ubuntu0.3`, verified
2026-11-24, and the .deb was confirmed to contain
`lib/x86_64-linux-gnu/libtinfo.so.5`). If the pool listing ever
stops resolving, the fallback is switching `runs-on` to
`ubuntu-22.04` (jammy carries `libtinfo5` natively).

**What was NOT chosen, and why:**

- **AOSP prebuilt Clang (e.g. clang-r383902, Clang 12.0.5) + GCC
  4.9** — the combination the sibling LostPrime kernel
  (`kurtnettle/android_kernel_samsung_sm7150`) actually uses in
  its CI (clang-r596125), but fetched from a URL in a repo secret
  (`TOOLCHAIN_DDL`) — not public, so not usable here. The public
  AOSP archive URLs were not verified in this step, and the fetch
  is two multi-hundred-MB downloads instead of one clone. This is
  the documented fallback if proton-clang fails (see §5).
- **Neutron Clang** — modern Clang (17/18), too new for a 4.14
  tree; 4.14 + Clang 17 has known breakage. Not attempted.
- **Eva GCC / arter97 arm64-gcc** — GCC-only; the tree's build
  was already written around Clang (`REAL_CC`), and the
  proton-clang recipe is better documented for this exact tree
  shape. Not attempted.

**Clone size, unmeasured:** the proton-clang repo is 13.6 GB with
full history (GitHub API `size`); a `--depth=1` shallow clone is
far smaller but was not measured here (no downloads in this
step). The workflow logs `du -sh` of the toolchain dir via the
`df -h` steps so the first run records the real number. If the
shallow clone turns out to be unexpectedly large, the mitigation
is a release tarball instead of a clone — do not guess a size in
advance.

## 2. What the workflow does

File: `.github/workflows/build-kernel.yml`. Trigger:
`workflow_dispatch` only, from the Actions tab ("Build kernel
(m51)"). Inputs:

| Input | Default | Meaning |
|---|---|---|
| `kernel_ref` | `4d83f24bf0b0a32de8066096c0b7eb00d53b3a79` | Kernel source ref in `kkisdevil/android_kernel_samsung_sm7150` (verified to exist 2026-11-24: "Change config flags to satisfy FCM"). Change it to build a newer fork commit without editing YAML. |
| `toolchain_ref` | `9fb011b183fe7e69b04b873ef6533b4b077e3c5e` | proton-clang commit. Frozen; change only if the toolchain itself is replaced. |

Steps, in order:

1. Check out this repo (defconfig + docs).
2. Check out the kernel fork into `kernel-src/` at `kernel_ref`
   (depth 1).
3. Check out proton-clang into `toolchain/proton-clang/` at
   `toolchain_ref` (depth 1).
4. Free disk space (GitHub-hosted standard runners have ~14 GB
   free SSD; kernel source + toolchain + build output approach
   that — same pattern as the UN1CA build workflow).
5. Install build deps (`bc bison flex libssl-dev libelf-dev
   libtinfo5`).
6. Put proton-clang `bin/` on `PATH`.
7. Record versions: `clang --version`, kernel HEAD + log line,
   defconfig SHA-256 + line count, `tools/dtc` presence, `df -h`.
8. Copy `kernel/m51_defconfig` → `kernel-src/arch/arm64/configs/
   m51_defconfig` and verify its SHA-256 against the draft hash
   `bcbab559…` — the build never runs from a defconfig that is
   not byte-identical to the reviewed draft.
9. Gates 1–7 (see §3), then `savedefconfig`, then upload
   artifacts (14-day retention): `Image.gz-dtb`, `Image.gz`,
   `.config`, `savedefconfig`, `dropped-symbols.txt`,
   `olddefconfig.log`, `build.log`.

It commits nothing back and flashes nothing. The `savedefconfig`
output is an artifact; a human reviews its diff and commits it
back as the canonical `m51_defconfig` (plan §6 item 3).

## 3. The 8 gates (plan §6)

| # | Gate | How the workflow checks it | Fail means |
|---|---|---|---|
| 1 | `make m51_defconfig` completes | The make step itself; `out/.config` must exist | Kconfig syntax error in the draft, or the file did not land in the tree |
| 2 | `olddefconfig` dropped symbols recorded | Python diff of input defconfig vs `out/.config` (enabled options only); full dropped list printed + saved to `dropped-symbols.txt`; job FAILS if any of `DISPLAY_SAMSUNG`, `DRM_MSM`, `WLAN`, `SECURITY_SELINUX_DEVELOP`, `FS_ENCRYPTION`, `SECCOMP_FILTER`, `FS_ENCRYPTION_INLINE_CRYPT`, `ANDROID_BINDER_IPC`, `ASHMEM` was dropped | The driver is missing from the crDroid tree — the plan must change (carry the driver from the a71 tree, or fall back to the a71 kernel as base). A Samsung debug/diagnostic symbol dropping is acceptable and does not fail the gate. |
| 3 | `savedefconfig` committed back | Workflow uploads `out/defconfig` as `savedefconfig` + prints the diff vs the draft (informational). The commit-back is manual, after review. | — (not a job gate; the diff is the review material) |
| 4 | Build completes; `Image.gz-dtb` fits the 64 MB boot partition | `out/arch/arm64/boot/Image.gz-dtb` exists, ≥ 1 MB (a real image, never a stub) and < 67,108,864 bytes | Build error (log is the artifact), or an image that cannot fit the boot partition |
| 5 | Version string is `4.14.357-openela` | `make -s kernelrelease` must print exactly `4.14.357-openela` | Wrong tree built (`4.14.190`/`4.14.336` = the a71 tree, not crDroid) |
| 6 | EROFS in the built kernel | `.config` has `CONFIG_EROFS_FS=y` and `CONFIG_EROFS_FS_ZIP=y`; `CONFIG_EROFS_FS_ZIP_LZMA` must be absent | EROFS backport not enabled (LZ4-only is the documented limit — an LZMA-compressed EROFS GSI cannot be mounted by this kernel, see gsi-verification.md §3) |
| 7 | SELinux permissive possible | `.config` has `CONFIG_SECURITY_SELINUX_DEVELOP=y` | A permissive boot image cannot switch SELinux to permissive |
| 8 | Boot test | NOT in this workflow — needs the physical m51: flash the permissive boot image, boot to fastboot/download at minimum, then the HyperOS DSU trial. A kernel that builds but does not boot is not a pass. | Record the boot result with the log; do not call the kernel done on a green build alone |

Two deliberate quirks the gates already account for:

- **Duplicate options in the draft.** The porter section appends
  `CONFIG_CPU_BOOST=y` and `CONFIG_MSM_NPU_V2=y` after earlier
  `# CONFIG_… is not set` lines for the same symbols. Kconfig
  resolves duplicates last-wins, so `olddefconfig` settles them
  to `=y` — they are NOT dropped symbols. The Gate 2 parser
  builds its dict sequentially (last assignment wins), which is
  exactly Kconfig's semantics; verified locally against the real
  defconfig (both parse to `y`).
- **`Image.gz-dtb`, not `Image`.** The old script's last line
  copied plain `Image`; this device boots `Image.gz-dtb`. Gate 4
  checks the `-dtb` file only.

## 4. How to trigger the first build

1. Upload `.github/workflows/build-kernel.yml` and
   `docs/kernel-build.md` to `kkisdevil/m51-hyperos` (browser
   web-upload flow, as with the other files; do not upload
   concurrently with another upload to the same repo).
2. GitHub → `kkisdevil/m51-hyperos` → Actions → "Build kernel
   (m51)" → Run workflow → leave the defaults → Run.
3. Watch the run. Expected wall time: toolchain clone + build on
   a 4-vCPU runner is roughly 15–40 minutes (unmeasured — record
   the real time from the first run).
4. On green: download the `m51-kernel-<run>` artifact, check
   `dropped-symbols.txt` and the `savedefconfig` diff, then
   commit the reviewed `savedefconfig` back as
   `kernel/m51_defconfig` (replace the draft) with the dropped
   symbols named in the commit message. Update
   `docs/kernel-defconfig-plan.md` §7 with the recorded
   `olddefconfig` list.
5. On red: read the failed gate first (the gates are ordered so
   the failure names the cause), then §5 below.

## 5. If the build fails

| Symptom | Likely cause | Fix |
|---|---|---|
| `E: Unable to locate package libtinfo5` at the install step (exit 100) | `libtinfo5` is not in the noble (24.04) repos at all — the package was dropped with ncurses 6.4 | Do NOT add it to the apt install line. Install the other deps via apt and fetch the current jammy `libtinfo5` .deb from the Ubuntu security pool, resolving the filename from the pool listing (a pinned version 404s when superseded). Fixed 2026-11-24 (run #1 → run #2). |
| `clang: error while loading shared libraries: libtinfo.so.5` at the version step | `libtinfo5` not installed (the pool fetch failed silently, or the step was skipped) | Check the install step's log for the pool fetch; if the pool listing is unreachable, switch `runs-on` to `ubuntu-22.04` (jammy has `libtinfo5` natively) |
| `No space left on device` mid-build | Runner disk (~14 GB) exhausted by source + toolchain + output | Extend the free-disk step (drop more preinstalled dirs); check the `df -h` lines in the log for the real usage |
| `make m51_defconfig` fails | Kconfig syntax error in the draft, or the copy step's hash check caught a drifted file | Read the error; fix the draft, re-upload, re-run |
| Gate 2 fails on a boot-critical symbol | The driver is missing from the crDroid tree | Stop (plan §6 item 2): carry the driver from the a71-devs kernel tree, or fall back to the a71 kernel as the base. Do not ship a kernel missing `DISPLAY_SAMSUNG`/`DRM_MSM`/`WLAN`. |
| Gate 2 drops only Samsung debug/diagnostic symbols | Expected — the a71 full config carries symbols the crDroid tree never had | Acceptable: record them in `dropped-symbols.txt` + plan §7, continue |
| Build error mentioning an inline-asm or builtin symbol | Clang 13 vs 4.14-isms | First try the documented fallback: AOSP Clang r383902 (Clang 12.0.5) + GCC 4.9 from `platform/prebuilts/clang/host/linux-x86` and `platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9`, using the plan §5 command (`CROSS_COMPILE=<gcc-4.9-prefix> REAL_CC=<clang>`). The exact archive URLs were NOT verified in this step — verify them with HEAD requests before wiring them in. If that also fails, the error is in the tree, not the toolchain — read the failing file, not the toolchain. |
| Gate 5 prints `4.14.336` or `4.14.190` | Wrong tree checked out (a71 instead of crDroid) | Check `kernel_ref` input and the fork's HEAD in the log |
| Gate 6 fails on EROFS | The EROFS backport symbols did not survive `olddefconfig` | Check whether `fs/erofs/Kconfig` exists at the checked-out commit; if the backport is absent at that ref, the defconfig's EROFS lines are dead and the GSI must be ext4 (or the backport carried in) |
| `savedefconfig` diff is huge | `olddefconfig` normalised hundreds of options (defaults filled in) | Expected on the first build — review the diff, do not commit it blind; the canonical config is the reviewed one, not the raw output |

## 6. Open items (filled in by the first build)

- [ ] `olddefconfig` unknown-symbol list — none recorded yet (no
  build has run). Comes from `dropped-symbols.txt`.
- [ ] Real wall time + toolchain clone size + disk usage — record
  from the first run.
- [ ] `savedefconfig` commit-back — manual, after reviewing the
  diff (plan §6 item 3).
- [ ] `DISPLAY_SAMSUNG` / `DRM_MSM` / `WLAN` existence in the
  crDroid Kconfig tree — unproven until the first `olddefconfig`
  (Gate 2).
- [ ] Boot test on the physical m51 (Gate 8) — needs the phone.
- [ ] GSI compression check — verify the Mystic `spring` HyperOS 2
  image is LZ4-compressed EROFS (or ext4); if it is lzma EROFS,
  this kernel cannot mount it (§3 gate 6, gsi-verification.md §3).

## 7. Validation performed locally (no build run)

- Workflow YAML parses (`yaml.safe_load`; the `on:` key reads as
  boolean `True` under PyYAML's YAML 1.1 handling — GitHub parses
  it correctly, and the repo's own `validate.yml` uses the same
  loader).
- All 13 embedded shell blocks pass `bash -n` (extracted and
  checked one by one).
- Gate 2 parse logic tested against the real
  `kernel/m51_defconfig`: duplicates resolve last-wins
  (`CPU_BOOST`/`MSM_NPU_V2` → `y`); boot-critical symbols all
  parse to `y`.
- Every local path the workflow references exists in the repo
  (`kernel/m51_defconfig`, `docs/kernel-defconfig-plan.md`).
- `shellcheck` is not installed on this VM, so the embedded shell
  was not shellchecked locally — the repo's `validate.yml` runs
  shellcheck on `scripts/*.sh` in CI (the workflow's inline shell
  is not covered by it; keep the blocks short and `set -euo
  pipefail` in every one, as done here).
- No toolchain, kernel, or image was downloaded in this step
  (metadata/HEAD checks only).

## 8. Sources

- `kdrag0n/proton-clang` — GitHub API 2026-11-24: exists, not
  archived, default branch `master`, HEAD `9fb011b1…`
  (2021-05-22, "Update to 20210522 build"); `bin/` contents
  listing (142 entries: `clang`, `ld.lld`, `llvm-ar`,
  `aarch64-linux-gnu-{as,ld,ld.bfd,objcopy,…}`, NO
  `aarch64-linux-gnu-gcc`); README (recipe `CC=clang` +
  `CROSS_COMPILE=aarch64-linux-gnu-`, "users do not need to
  download separate GCC toolchains", built on Ubuntu 18.04 /
  glibc 2.27).
- `packages.ubuntu.com` — `libtinfo5` page HTTP 200 for noble
  (24.04) and jammy (22.04), incl. the noble amd64 download page,
  checked 2026-11-24.
- `kkisdevil/android_kernel_samsung_sm7150` — API 2026-11-24:
  commit `4d83f24b` exists ("Change config flags to satisfy FCM").
- `kurtnettle/android_kernel_samsung_sm7150`
  `.github/workflows/build_kernel.yml` (master) — uses AOSP Clang
  r596125 from a secret URL (`TOOLCHAIN_DDL`); not public, so not
  usable as the pin — recorded as evidence that AOSP Clang also
  builds this tree.
- Prior docs: [kernel-defconfig-plan.md](kernel-defconfig-plan.md)
  §2–§6 (blocker, diff, resolution, corrected command, gates);
  [tree-takeover.md](tree-takeover.md) §8/§10 (Phase 0 status);
  `m51-rom-builder` skill §6.
