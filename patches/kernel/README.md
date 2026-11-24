# Kernel patches (porter-side)

Patches applied to the kernel source **at build time** by the
`build-kernel.yml` workflow ("Apply porter kernel patches" step),
after the kernel fork is checked out and before Gate 1. They are
applied with `git apply` inside `kernel-src/`, in filename order.

## Rules

- **Porter-side only.** The pinned kernel ref
  (`kkisdevil/android_kernel_samsung_sm7150` @ `4d83f24b`) is never
  modified in its own repo. A patch lives here, not as a fork commit,
  so the pin stays reproducible and the change is reviewable in the
  port repo.
- **Minimal + traceable.** Each patch fixes one build failure (or one
  port requirement), touches as little as possible, and carries the
  failing run number + error in its header. Where an upstream (CAF /
  LineageOS / AOSP) form of the fix exists, say so in the header.
- **Fail loudly.** The workflow runs `git apply --check` first; if a
  patch no longer applies (upstream moved the code), the build fails
  at the patch step with a clear error instead of silently building
  the unpatched tree. Fix the patch, do not skip it.
- **Never patch the defconfig.** Config changes go in
  `kernel/m51_defconfig`, not in a patch.

## Patches

| File | Fixes | What it does |
|---|---|---|
| `0001-drm-msm-sde-fix-undeclared-mode.patch` | Kernel build run #3 (2026-11-24): Gate 3, `drivers/gpu/drm/msm/sde/sde_rm.c:1605: error: use of undeclared identifier 'mode'` (Clang 13) | `_sde_rm_populate_requirements()` has no variable named `mode` in scope; the debug trace wants the requested display-mode width, which is `crtc_state->mode.hdisplay` (`struct drm_crtc_state` embeds the requested `struct drm_display_mode` as `mode`). Trace-only line (`SDE_EVT32`); no behaviour change. Same form as upstream CAF's `sde_rm.c`. |
| `0002-msm-npu-fix-debugfs-obj-overwrite.patch` | Kernel build run #4 (2026-11-24): Gate 3, vmlinux link, undefined reference to `npu_debugfs_init` / `npu_debugfs_deinit` | The NPU Makefile builds the debugfs file and the driver with `:=` on the same `obj-y` variable (`obj-$(CONFIG_DEBUG_FS) := npu_debugfs.o` then `obj-$(CONFIG_MSM_NPU) := msm_npu.o`); with both configs `=y` the second assignment overwrites the first, so `npu_debugfs.o` is never compiled — verified in the run #4 log (no `CC ... npu_debugfs.o` line; all five `msm_npu-objs` members compiled). Fix: `:=` → `+=` on both lines. |
| `0003-qdf-define-qdf-bug-without-wlan-debug.patch` | Kernel build run #4 (2026-11-24): Gate 3, vmlinux link, undefined reference to `__qdf_bug` | `__qdf_bug()` is defined only in `qdf_trace.c`, whose whole body is wrapped in `#ifdef WLAN_DEBUG` (off: `BUILD_DEBUG_VERSION := n`), while `PANIC_ON_BUG=y` (because `CONFIG_SLUB_DEBUG=y`) makes `QDF_BUG()` emit extern calls to it — verified: `qdf_trace.o` WAS compiled in run #4 but provides no `__qdf_bug`. Fix: define `__qdf_bug()` after the closing `#endif /* WLAN_DEBUG */`, guarded by the header's exact extern-branch condition (`PANIC_ON_BUG` + `CONFIG_SLUB_DEBUG`) plus `!WLAN_DEBUG` so it cannot duplicate the original definition in a debug build. **CORRECTION 2026-11-24:** the first version of this patch failed to apply in run #5 (`patch does not apply` at `qdf_trace.c:3991`) — it was written against a reconstruction ending at line 3993, but the real file ends with a trailing blank line (line 3994). Regenerated from the real file at the pinned commit; hunk now includes the trailing blank line as context; verified with `git apply --check` against that exact file. **CORRECTION 2, 2026-11-24:** the corrected version applied cleanly in run #6 but failed Gate 3 ("4 errors generated", qdf_trace.c:4005-4009) — the appended definition was bare after the closing `#endif /* WLAN_DEBUG */`, but every #include in the file sits INSIDE that guard, so the block had no declarations: BUG() implicitly declared, __qdf_bug with no prototype, qdf_export_symbol undefined. Fix: the block now brings its own `#include <linux/bug.h>` + `#include <linux/export.h>`, a forward declaration, and the kernel's EXPORT_SYMBOL directly. Same guard, same body, same hunk anchor. |
