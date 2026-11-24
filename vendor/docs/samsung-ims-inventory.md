# Samsung IMS staging inventory (OneOS)

Inventory from **Arnav3078/OneOS-SM7150**
`docs/samsung-ims-in-guest.md` (status 2026-10-29, Apache-2.0),
documented in `research/09b-arnav-ports.md` §3.3. Credit: Arnav3078
+ fahadalijaved/OneOS. This doc is OUR checklist for Phase 3 IMS
work — not a copy of their code.

## The problem

On a Samsung phone, VoLTE is not in the modem or the vendor — it is
the system app `com.sec.imsservice` (`/system/priv-app/imsservice`,
~10 MB; the SIP stack is its `libsec-ims.so`) reaching the modem
through `vendor.samsung.hardware.radio.channel.ISehRadioChannel/imsd`
and the host daemon `/system/bin/imsd` over `/dev/socket/imsd`. A
guest/system that has no `ImsService` falls back to 3G for calls,
and on a VoLTE-only carrier it gets no calls at all.

## The third IMS approach

Our plan's IMS answer is phh Floss IMS per carrier (gap #1, the #1
daily-driver blocker). OneOS offers a third path: **stage Samsung's
own imsservice into the guest/system** instead of replacing IMS.
It is staged + offline-checked, NOT yet booted on a phone — ranked
behind Floss IMS on proof, ahead of the ColorOS bypass (which gives
up VoLTE entirely).

## The inventory (what to stage)

- The APK: `com.sec.imsservice` (`/system/priv-app/imsservice`),
  copied as a priv-app (OneOS names it `OneOSSecIms`).
- The jars: `imsmanager`, `rcsopenapi`, `vsimmanager`, `EpdgManager`.
- The three native libs (incl. `libsec-ims.so`, the SIP stack).
- The privapp-permissions list for the app.
- One UI's `framework.jar` as a compat jar (`oneos-secims-compat.jar`):
  a 307-class transitive closure — 98 Samsung Wi-Fi classes, 48
  `com.samsung.android.ims` classes, 28 telephony sysprops.
- The package-manager carve-out (OneOS: `guest_sec_ims_signature.py`),
  checked offline (apktool reassembles, check-dex passes).

## How to use this in Phase 3

1. Start with Floss IMS per carrier (the plan's answer). Keep this
   inventory as the alternative if Floss stalls on Indian carriers.
2. If staging is attempted: copy the inventory above into the system
   image, apply the package-manager carve-out, and verify offline
   (apktool reassembles, check-dex passes) before any device test.
3. On device: check `ImsService` binds, then test a VoLTE call on
   Jio first, then Airtel, then Vi. Emergency calls (112) remain
   unimplemented in Floss IMS — staging Samsung's own service does
   not automatically fix 112 either; test it separately and say so.

## What would break

- Staging the APK without the jars/libs/permissions: the service
  crashes at bind time (missing classes).
- Staging without the compat jar: the 307-class closure is missing
  and the service fails with ClassNotFound at runtime.
- Assuming staging = working VoLTE: it is unproven on a phone.
  The inventory is a checklist, not a proof.
