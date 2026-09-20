# 1.11.3 — restore the live artwork

## Observed source problem

The published 1.11.2 tree (`62fdb946`) did not contain the Courants II bank. Espace's illustration used one 80-second low-amplitude satin wave. Its driver also required SwiftUI `scenePhase == .active` and a zero-sized AppKit visibility probe. Previous validation separately tested geometry at supplied timestamps and the timer in isolation; it did not establish that the complete live view actually advanced after window presentation or reattachment.

The user's precise local failure cannot be reproduced on the disconnected Mac. The absence of the bank and restrictive lifecycle implementation are source observations, not proof of the local preference or OS condition that froze that installation.

## Implementation

Recovered the original twelve Courants II mathematical motifs from the existing delivered kit, not copied competitor assets. `MotionGeometry.swift` retains its formulas. Only the main listening pane renders them. Covers, menu-bar logo and menu-bar player remain static. No video, web view, network texture or third-party rendering dependency was introduced.

Automatic mode maps the current music to its visual identity. The Animation menu chooses a different identity without selecting or starting audio. The new `onde.espace.artworkChoice` preference defaults to `automatic`; an unknown value safely follows the music. Existing Show artwork, Animate artwork and Reduce Motion preferences are respected, never silently reset. A hidden illustration has a Show animation recovery button. Paused artwork has Resume visual. Reduced motion explicitly names macOS or Onde and links to the existing settings sheet.

`EspaceArtworkWindowProbe` observes its own hosting NSWindow, including visibility, occlusion, key/main-window changes, minimization, application hide/unhide, resize and reattachment. It occupies the real surface bounds and evaluates a coalesced callback at delivery time. The decorative view no longer requires an active SwiftUI scene. A visible inactive window uses 12 Hz/economy detail rather than appearing frozen. A foreground window requests 24 Hz. Hidden/fully occluded/minimized windows, Quiet view, a sheet, explicit visual pause, Reduce Motion and serious thermal state stop the clock. Stale queued timer ticks are invalidated by a generation counter. Paused time never catches up.

Budgets: 3,616 points per foreground update and 1,620 in economy. These are work limits, not measured frame rates or battery life. A 450 ms opacity transition may briefly retain two surfaces. The animation clock is separate from AppModel/SessionClock; it never starts audio or records listening time.

## Verification

Eight additional core tests cover the bank, mapping, malformed preference fallback, visible deformation, closed cycles and numerical boundaries. The new `Tools/test_live_artwork.py` launches the compiled app in a private muted profile. `EspaceMotionCapture` uses the complete EspaceRootView in a real NSWindow, without overriding scene phase, bypassing visibility or supplying synthetic animation time. It compares rendered pixels while the production Timer/RunLoop runs, checks all twelve choices, pause/resume, hidden artwork, reduced motion, sheets, Quiet view, order-out/order-in, minimize/restore and full occlusion. It records natural frame timestamps. Its read-only weak-driver instrumentation is excluded from production builds.

The existing 1.11.2 transport, listening, daily-ledger and fixed-logo checks remain in the native workflow. Final counts belong to the exact successful CI run recorded on the pull request. Programmatic AppKit and model actions are not an exhaustive pointer/VoiceOver test; no prolonged GPU/energy or local-device result is claimed.

## Apple implementation references

- Window occlusion describes whether any part of this window is exposed: https://developer.apple.com/documentation/appkit/nswindow/occlusionstate-swift.property
- Apple's window-level visibility and energy guidance: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/WorkWhenVisible.html
- Scene phase and foreground interactivity are distinct from testing a particular native window's exposed bounds: https://developer.apple.com/documentation/swiftui/scenephase/active

No change to the DSP, audio files, session accounting, fixed status icon, user data format or automatic installation policy.
