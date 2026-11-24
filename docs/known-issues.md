# Known issues — what to expect from HyperOS on the m51

> **Nothing in this file is confirmed on the m51 yet.** Every entry comes
> from HyperOS GSI reports on *other* Samsung models (S10 series, A21s,
> A54, A71) or from the generic Samsung GSI guides. The m51 column will
> only be filled in once someone actually boots and tests it. If you
> test, please report — a "works" is as valuable as a "broken".

## Expected broken (from other Samsung models)

| Issue | Evidence (other models) | Status on m51 | Workaround |
|---|---|---|---|
| Camera app not installed | DroidWin guide; A21s XDA report | Expected | Install GCam (a Google Camera port). Quality and features will be limited — the HyperOS camera expects Xiaomi camera HALs. |
| SIM / RIL not working for some | DroidWin guide; A21s report | Expected — biggest daily-driver risk | None known. Vendor-HAL dependent; try the other GSI build. |
| VoLTE / VoWiFi | Samsung GSIs in general; LineageOS on m51 lists VoLTE as not ported / needs testing | Expected broken | None. Calls fall back to 2G/3G where available. |
| Setup wizard dead / nuked | DroidWin guide; A21s report | Expected | Finish setup over adb — see [install.md](install.md#6-first-boot). |
| Brightness bug | DroidWin guide; A21s report | Expected | None known yet. |
| Flashlight | A21s report | Expected | None known yet. |
| Status-bar glitches | A21s report | Expected | None known yet. |
| Gesture navigation partly broken (back only) | A21s report | Expected | Use 3-button navigation instead. |
| Latency opening/closing the Phone app, launcher bug on first boot | A21s report | Expected | None known yet. |
| No 120 Hz in Settings | DroidWin guide | Not applicable — the m51 is a 60 Hz panel. (The DroidWin `adb shell settings put … 120` commands do not apply here.) | — |
| Play Integrity / banking apps fail | Unlocked bootloader + GSI, same as any custom ROM | Expected | None in this project. Same caveat as the UN1CA builds. |
| Knox | Tripped permanently by the unlock itself | Certain | Cannot be undone. Samsung Pay / Secure Folder are lost. |

## Unknown on m51 (needs a real device test)

| Question | Why it matters |
|---|---|
| Does the side-mounted capacitive fingerprint sensor work? | AOSP ROMs got it working on m51, but Xiaomi's fingerprint stack is different. Unknown. |
| Is the camera usable via GCam? | The camera app is missing; whether GCam works acceptably on this vendor is untested. |
| Does HyperOS 3 (Android 16) boot at all on the Android 12 vendor? | The S21+ HyperOS 3 boot explicitly needed an A16 vendor. The m51 has no newer vendor. |
| Does the ~4 GB system image fit the m51's super partition as laid out? | The flash guide deletes the `product` and `system_ext` logical partitions to make room; whether that is enough is untested. |
| Do Wi-Fi and mobile data work? | The A54 DSU report had *neither* Wi-Fi nor data working. On other models they work. Model-dependent. |
| How smooth is it, really? | HyperOS is famously smooth on Xiaomi hardware. On the m51's old vendor and 730G it is unproven — do not assume the smoothness transfers. |

## What the A71 precedent tells us

The Galaxy A71 (same SM7150 platform) HyperOS 2 port by seelenchik
(XDA, 2025-06-29) was described by its author as **hard to flash and
unstable**, and is no longer updated. That is the honest expectation for
the m51 too: a bootable experiment, not a daily driver, at least at
first.

## Reporting a test

When you test, report these six things — they are the open questions
from the research:

1. Which GSI build (exact filename) and which route (DSU / full flash)?
2. Does it boot to the home screen?
3. Do SIM / calls / mobile data work?
4. Does the side fingerprint sensor work?
5. Is the camera usable via GCam?
6. Does HyperOS 3 boot, or only HyperOS 2?
