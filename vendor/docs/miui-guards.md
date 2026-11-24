# MIUI services guard patterns (OneOS)

Patterns from **Arnav3078/OneOS-SM7150** `docs/hyperos.md` +
`switcher/patches/miui_guards.py` (Apache-2.0), documented in
`research/09b-arnav-ports.md` §3.4. Credit: Arnav3078 +
fahadalijaved/OneOS. This doc is OUR adaptation of the patterns for
the L6 framework patches — not a copy of their code.

## The patterns

The HyperOS guest image (built from the Xiaomi 18 Fold / lhasa CN
OTA, OS4.0.26.0.XPNCNXM — HyperOS 4, MysticGSI patch set) needs
guards in `miui-services.jar` so Xiaomi services that assume a
Xiaomi phone do not break a non-Xiaomi host:

- Neuter recovery / factory-reset / package-install / memory-extension /
  OEM-netd methods: each becomes a bare return.
- `RescuePartyImpl` sets `sys.powerctl` itself — redirect it to a
  guest-scoped property (`oneos.guest.powerctl` in OneOS; our port
  needs its own scoped name, never the host's).
- `MiuiGcImproveImpl`'s Xiaomi-vold call removed.
- `ShutdownThreadImpl`'s bootanim setprops removed (the guest shares
  the host's init — starting the host's boot animation would cover
  the host after return).
- `apprecovery.proinstaller.jar`: `InstallService.onStart` returns at
  entry — the auto-install service is neutralised, not removed.
- Weaver/gatekeeper reach only through the guarded `getWeaverService`
  (null in the guest). `Runtime.exec` calls in miui-services.jar only
  read.

## The rules that make the patterns safe

1. **Fail-closed: every target must match exactly once, or the build
   stops.** A guard that matches zero times means the method moved
   (new HyperOS version) — silently skipping it would ship an
   unguarded service. A guard that matches twice means the patch
   would hit the wrong method. Either way: stop the build.
2. **Hash-checked guarded jars.** Every guard is hash-checked
   (`files.sha256`) and bound over the guest at prepare time; an
   image with miui-services.jar does not start unless both guarded
   jars are in place.
3. **Neutralise, do not remove.** A method that returns immediately
   keeps its callers working; deleting the method (or the service)
   breaks every caller. Same rule as the TEE-daemon neutralisation
   in the ColorOS port.
4. **Scope every hook.** The A03 precedent scopes its AccountManager
   hook to `com.xiaomi` / UID 1000 only. Never globally disable
   signature checks, never fake authentication.

## How to use this in L6

When writing a smali patch for `miui-services.jar` (or any Xiaomi
framework jar): name the exact method, write the guard as a bare
return (or the scoped redirect), add the fail-closed match check to
the patch script, and record the jar's SHA-256 in the patch's
manifest. First-failure triage (port-plan.md §1 rule 3) decides
which guard is needed — never batch-guess guards.
