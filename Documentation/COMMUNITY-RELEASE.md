# Community release checklist

A release candidate is not a published release. Before a Reddit announcement, the public download must point to the exact final tested build, and no required check may be failing, cancelled or pending.

## Installation and trust

Onde requires macOS 14 or later. Use the universal ZIP and checksum from the official GitHub release, unzip it, and move Onde.app into /Applications or ~/Applications. Quit any older instance before replacement. Personal data is stored separately under ~/Library/Application Support/Onde; do not delete that folder to install an update.

Community builds are ad-hoc signed, **not Apple-notarized**. A checksum detects changed bytes; it does not establish a verified Apple developer identity or certify the absence of malware. macOS may block first launch. Only a person who trusts the source should consider Apple's per-app approval process in System Settings > Privacy & Security after attempting to open the app. Never disable Gatekeeper, script removal of quarantine, export signing keys or require an administrator installer. A damaged-app or malware alert must be investigated, not treated as an unidentified-developer prompt.

[Apple: safely open apps on your Mac](https://support.apple.com/en-us/102445).

## First-listen contract

The app opens silently. Browsing Focus, Relax and Meditation changes the catalog, not the current music. A music row or Start begins playback; the star changes the default without playing. Adjust sound contains independent music/background levels and tone controls.

Pause freezes the session and daily activity. Play resumes the existing music; selecting music after a pause starts that selection from its beginning. End session resets the current stopwatch, not today's activity. Silent Meditation can retain its timer and chimes; Focus and Relax with no enabled sound pause. Mute is not Pause. Closing the main window leaves the menu-bar player available; Quit exits the application.

Chime times in the interface are minutes. A draft is not saved until Apply. Unapplied edits remain protected when closing or quitting; review, apply or discard them explicitly. A zero master or chime level makes Listen silent.

Imports are private copies. Removing one preserves its original. Deleting a saved mix removes the configuration, not the current sound, imported files or history. Ambiguous command-line names are rejected; use the stable ID from `onde mixes`.

## Required evidence

Record the final source revision, native unit/lifecycle/UI results and universal-candidate gate. Each compatibility job must verify and exercise the identical ZIP, not rebuild or re-sign it. Verify both architectures, the bundled CLI, native helper upgrade, failed-start rollback and final ZIP acceptance. Preserve failed runs and their explanations; unlimited retries are not validation.

Screenshots and CLI tests alone do not prove interactive controls. Exercise the native UI, review final captures and verify search empty states, default selection, transport, dirty edits and deletion confirmation. The standalone Apple framework diagnostic is not an app test: the affected Intel virtual Canvas baseline fails, while Onde's required Intel app tests must pass with its narrowly scoped software renderer.

Hosted muted tests do not establish browser/Finder/Gatekeeper behavior on a consumer Mac, physical audio-device reconnect, complete keyboard/VoiceOver navigation, subjective musical quality or prolonged energy use. Record these limits. Developer ID signing and notarization should precede a frictionless general-public launch; no certificate is created or exported by the audit.

## Public introduction

Disclose the developer relationship, macOS requirement and community signing status next to the download. Do not promise clinical benefits, competitor superiority or universal absence of bugs. Use genuine native captures without personal data. Playback works offline; optional update checks contact GitHub, which receives ordinary network metadata, not the private library.

Review the target community's current self-promotion rules before posting. Do not mass-crosspost or publish raw state.json, personal audio, private paths or listening history. A prepared announcement is a draft, not authorization to post automatically.
