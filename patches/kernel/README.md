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
