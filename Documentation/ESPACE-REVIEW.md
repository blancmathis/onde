# Espace — final review notes

20 September 2026. Supplements ESPACE.md; no change to the audio engine or the production release.

## Final settings pass

Settings tabs remain visible while their content scrolls. Switches use a shared trailing alignment rather than following labels of different lengths. Slider accessibility values include their visible unit. Chime draft state belongs to the settings sheet, so switching sections does not destroy it. An unapplied edit is explicitly labelled and can be reviewed or discarded. Done, Escape and the Advanced page's navigation ask before discarding an edit; interactive dismissal is disabled while an edit is pending. External CLI navigation can still replace the sheet, and quitting the app is not blocked: an unapplied draft is not a persisted preference.

A clean draft follows externally changed markers. A dirty draft is preserved and blocks Apply after a conflict until the current saved times are reloaded. Apply re-reads the latest markers before validation. Inputs are finite, positive, at most 1440 minutes and at most 32 entries; duplicates are removed and times sorted. Empty input explicitly removes markers. Twelve focused tests cover this transaction without invoking playback.

## Competitive reference and design choices

Endel's official product page describes generative visuals associated with soundscapes and a streamlined Mac interface: https://endel.io/ . Brain.fm's official product page highlights activity-based modes, one-click starts and an infinite count-up timer: https://www.brain.fm/ . These are documented product descriptions, not a hands-on audit of every screen or current subscriber flow.

Espace's choices are our design decisions: one listening surface instead of animated cards; a visible, stable catalogue; browsing separate from starting audio; optional artwork; a genuinely still Quiet view; advanced controls revealed on demand. No competitor screenshots, artwork or audio are bundled, and no superiority, cognitive benefit or battery result is inferred from these references.

## Evidence and acceptance boundary

The dedicated pull-request workflow compiles native SwiftUI and runs the full macOS suite plus the existing 53-check listening integration test in a temporary muted profile. It records the exact checkout SHA and source archive. Seventeen native screen captures include all four settings sections and a compact window using the high-contrast AppKit appearance; the latter is not equivalent to a full system accessibility audit. Two additional surface phases and three real Timer/RunLoop checks cover geometric movement and clock lifecycle, not frame pacing.

The branch is for review, not silent replacement of a user's installation. Main was cc3b957 at recovery and did not contain the reported Courants integration. Reconcile any newer local or otherwise unavailable integration before merging. Existing roots remain available; only the main-window and menu-bar presentation entry points are switched. Live keyboard/pointer paths, VoiceOver, sustained GPU/energy measurements and personal visual approval remain local release checks. The source archive contains code and fetching/building tools, not a notarized standalone application.
