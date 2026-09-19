# Espace — a listening-first interface for Onde

Design revision: 19 September 2026. Native macOS SwiftUI implementation, not a web view.

## Scope and integration safety

The visible repository base was `cc3b957532ccbdb711f7615e1e8bdc4f43e4696b` on `main`, version 1.11.0. It did not contain the Courants motion-bank integration mentioned by the user. This branch must be reconciled with any newer, unpushed local changes before merging. Do not replace a working tree or the installed app blindly.

The redesign lives in `design/espace-ui-20260919`, PR #1. It changes the main-window and menu-bar presentation, not the audio engine. Legacy views remain in the repository; the two entry points in `OndeApp.swift` choose the new presentation. There is no sound-bank replacement, DSP change, migration of saved music, or change to the CLI protocol. No production release is published by the design-validation workflow.

## Design decision

Onde is a listening tool, not an animation browser. The current music and its transport occupy the main area. The collection sits beside it. Sound controls appear when requested. A single, optional satin surface provides a visual identity; individual covers remain still. The actual quiet view contains no artwork or animation clock.

The scoped palette is charcoal, ivory and three restrained mode accents. Six static cover families help recognise music without adding another animation. System type, native controls, visible focus treatment and explicit labels are used instead of an embedded browser or external font files.

## Behaviour contract

### Browsing versus listening

The Focus, Relax and Meditation segmented control changes the collection only. It does not select audio, start playback, reset elapsed time or change a saved default. When browsing a different mode, the collection explicitly names the unchanged current mode and offers “Show current”.

“Start Focus”, “Start Relax” and “Start Meditation” intentionally start the saved default. The existing Cmd-1, Cmd-2 and Cmd-3 shortcuts keep that behaviour. Clicking a music row intentionally plays it, using the existing AppModel selection policy. Plain Play resumes; selecting a piece after pausing starts the selected piece with its existing gentle entrance. Same-mode music selection preserves the stopwatch.

The row star changes only the starting default. Rows do not move after a star is selected. The dedicated Start card updates to show the default, avoiding a list that shifts under the pointer.

### Collection and keyboard

All 17 Focus compositions and the 8 shared Relax/Meditation compositions remain available. Search matches all entered words against the title, stable ID, authored description and displayed instrument details, ignoring case and accents. Search never changes playback. Empty results show a clear-search action. Cmd-F focuses search; Escape clears the query or leaves Quiet view. Existing session shortcuts remain available.

### Sound and settings

Adjust sound groups music/background balance, tone, transitions and advanced controls. Background Off hides its inapplicable amount slider. Master volume remains at the bottom of the main window and in the menu-bar player. These are separate levels, not alternate labels for the same control.

Settings is divided into General, Defaults, Meditation and Advanced. Resetting sound requires confirmation. Editing chime times uses an explicit draft and Apply action; changes made elsewhere cannot silently overwrite an edited draft. Choosing the suggested 10, 20, 30 values fills the draft without applying it. Empty chime times disable reminders. Existing personalised markers are not reset.

### Quiet view and artwork

Quiet view displays only the current music, count-up time, relevant chime information and essential transport, with a visible return action. No countdown or completion target is introduced.

Show artwork and Animate artwork are independent preferences. Hiding artwork removes its Canvas and clock from the view tree. Pause visual does not pause music. Reduce Motion from either macOS or Onde wins over the animation preference. A paused visual retains its phase; resuming does not catch up elapsed wall-clock time.

## Implementation map

| File | Responsibility |
|---|---|
| `EspaceView.swift` | Root layout, collection, current session and Quiet view |
| `EspaceComponents.swift` | Scoped tokens, buttons, optional surface and lifecycle-aware clock |
| `EspaceIdentity.swift` in OndeApp | Six static cover families and row focus treatment |
| `EspaceMenuBarView.swift` | Compact player without decorative animation |
| `EspaceSettings.swift` | Sound settings, defaults, chime draft and disclosure |
| `EspaceAccessibility.swift` | Effective system-plus-app motion preference |
| `ListeningDesign.swift` | Search, presentation details, geometry and clock policy |
| `EspaceIdentity.swift` in OndeCore | Stable cover-family assignment |
| `EspaceCapture.swift` | Compile-flag-gated, muted native snapshot capture |

New appearance preferences are the two boolean keys `onde.espace.visualMotion` and `onde.espace.showArtwork` in UserDefaults. They are not added to the audio state schema. CI uses a separate defaults suite.

## Performance and accessibility boundaries

The requested motion budget is 24 updates/second normally and 12 in Low Power Mode. Geometry per update is 9,520 points normally or 2,744 in economy. These are implementation budgets, not measured frame rates or battery results. At a music transition the outgoing and incoming surface may coexist briefly for an opacity crossfade; only one remains in steady state.

The clock is observed only by the artwork subtree. It is stopped while the surface is absent, motion disabled, Reduce Motion active, the scene inactive, the window not visibly exposed, or thermal state serious/critical. No video decoder, remote texture, third-party animation runtime or 3D engine is required.

Accessibility provisions include system controls, accessible names, keyboard focus treatment, decorative accessibility hiding, reduced-motion precedence and announcement of feedback. Disabled controls remain explicitly disabled. This is not a completed VoiceOver or WCAG certification. Inspect high-contrast mode, keyboard navigation and assistive technology on the user's actual Mac before general publication.

## Validation

The dedicated GitHub Actions workflow builds the actual app on macOS, runs the native test suite, renders the compiled SwiftUI views through NSHostingView in a muted temporary profile, packages an isolated application, and runs the existing listening integration suite through the real app's CLI/socket.

The artifact includes the exact source snapshot, checkout SHA, OS/Swift versions, complete logs, native PNGs and two separately rendered surface phases. The actual Timer/RunLoop driver is separately checked for progress, pause and resume. A source-parser pass on Linux is not treated as SwiftUI compilation. NSHostingView snapshots are not represented as full native pointer/keyboard automation. CLI integration tests exercise the same AppModel but not the hit targets in the new UI.

Before/after images use the old main-branch RootView and the new EspaceRootView, both compiled in the same test application. They do not claim to depict the user's unpushed Courants integration. The surface phase comparison establishes that rendered geometry differs with time; it is not a display-pacing benchmark.

Results belong to their exact workflow run and source SHA. See the PR validation record and the downloaded `QA/Espace/` artifact for counts and logs. Keep failed runs visible in GitHub rather than rewriting history.

## Remaining release gate

Reconcile local changes, review the actual screenshots, test the native window on the user's machine with keyboard and VoiceOver, measure with Instruments under sustained playback, then decide whether to merge. User preference and a controlled usability comparison are needed to judge whether this interface is better than Endel or Brain.fm; neither a screenshot nor passing tests establishes that claim.
