# FAQ

## Is this a real HyperOS port for the m51?

No. There is no from-source HyperOS port for the m51, and this project
does not build one. It is a **GSI bring-up**: a community HyperOS system
image (Mystic GSI) flashed
over the m51's stock vendor. A real port would be a multi-week job and
nobody is working on one — see the README.

## Has anyone booted HyperOS on the m51?

Yes, reportedly — on Telegram, via GSI. Telegram groups are not
web-indexed, so no link, group name, or build can be cited; the report
is user-reported and unlinked. No *public* report (XDA, GitHub, YouTube)
was found. That is why this project treats the GSI path as
proven-in-principle rather than purely theoretical, while still marking
everything as unproven until someone tests it in the open.

## Why HyperOS 2 first and not HyperOS 3?

The m51's vendor is frozen at Android 12 (VNDK 31, kernel 4.14).
HyperOS 2 is an Android 15 system; HyperOS 3 ships on Android 15 (e.g.
the Mystic `gold` build) as well as Android 16. The smaller the
system↔vendor version gap, the fewer HAL surprises. The S21+
HyperOS 3 boot explicitly needed an A16 vendor — the m51 has no newer
vendor to upgrade to. HyperOS 1 (Android 14) has the smallest gap of
all and is the safest fallback if HyperOS 2 fails.

## Will it be smooth? HyperOS is super smooth, right?

HyperOS is smooth on Xiaomi hardware. Whether that smoothness transfers
to the m51 — old vendor, Snapdragon 730G, Xiaomi framework talking to
Samsung HALs — is **unproven**. Do not assume it. The A71 precedent was
described as unstable. Test it and see; do not promise it.

## Will it be a daily driver?

Probably not at first, and maybe never. Expected problems: no camera app
(GCam workaround), SIM/RIL issues for some, VoLTE broken, setup wizard
dead, fingerprint unknown, Play Integrity failing. See
[known-issues.md](known-issues.md).

## Do I need TWRP?

For the **full flash**, yes — flashing goes through TWRP → fastbootd
(Samsung has no native fastboot). For the **DSU trial boot**, no — DSU
Sideloader + Shizuku (or root, or ADB mode) is enough. Both routes need
an unlocked bootloader.

## Can I go back to stock?

Yes. Flash the stock SM-M515F firmware with Odin, then Format Data in
stock recovery. Knox stays tripped — that cannot be undone.

## Will Knox / Samsung Pay / Secure Folder survive?

No. Unlocking the bootloader trips Knox permanently, before any GSI is
flashed. Widevine drops to L3.

## What about the camera?

The HyperOS camera app is not installed in the GSI (it expects Xiaomi
camera HALs). The workaround used on other Samsung models is GCam. How
well GCam works on the m51 vendor is untested.

## Does the fingerprint sensor work?

Unknown. The m51 has a side-mounted capacitive sensor. AOSP ROMs got it
working, but Xiaomi's fingerprint stack is different.

## Why is there no direct download link for Permissiver v5?

Because no direct URL was verified for this project. Get it from the
link in the DroidWin guide
(<https://droidwin.com/how-to-flash-hyperos-2-android-15-gsi-on-samsung/>).
If you find a stable direct link, please contribute it.

## Can I build my own HyperOS GSI instead of using Mystic's?

Yes — see Rakija-GSI-Tool
(<https://github.com/Orthoxodus/Rakija-GSI-Tool>), which builds GSI
ports from OEM firmware URLs (`url2GSI.sh <URL> -- ab HyperOS`). That
route is not documented in this repo yet; contributions welcome.

## I booted it — where do I report?

Open an issue on this repo (once it exists on GitHub) with the six
things in [known-issues.md](known-issues.md#reporting-a-test): GSI
filename, route, boot result, SIM/calls/data, fingerprint, camera.
A "works" is as valuable as a "broken".
