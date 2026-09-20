# Changelog

## 1.11.1 — Reliable update downloads

- Show real byte and percentage progress while downloading a release, with an explicit cancel action.
- Extend the verified download budget for slower connections and wait for temporary connectivity loss instead of appearing frozen.
- Clear stale paths from earlier releases before a new transfer, so an old verified archive is never presented as the current update.
- Add a direct browser fallback while retaining exact size and SHA-256 verification for in-app downloads.
- Report transfer and verification state through the local status/CLI snapshot.

## 1.11.0 — Five relaxation worlds

- Add Lagoon, Stillwater, Hearth, Reverie and Driftwood to the shared Relax/Meditation catalog without changing user defaults.
- Separate authored scores: warm ambient, acoustic piano, chamber ensemble, synthesized wordless choir, and wooden resonators with recorded harp.
- Eight-bar sentences, 96-bar chapters, common-tone sustained synthesis and slow overlapping acoustic envelopes. No forced noise, percussion or special-frequency claims.
- Preserve the seventeen Focus profiles, existing music, background controls, gentle entrances, scene crossfades, timers and personal data.
- Document controlled studies, conflicting results, evidence limitations and the distinction between production choices and clinical validation.
- Add planner, audio, transition and native catalog regression tests.

## 1.10.1 — Listening polish

- Refresh the in-app CLI guide for music choices, independent defaults and background sound.
- Fix shell quoting when copying saved-mix examples.
- Clarify the main-screen Music crossfade control.
- Preserve the 1.10 listening model, musical scores, saved preferences and transport behavior.

## 1.10.0 — One screen for listening

- Replace the sidebar, separate library and duplicated music pages with a single mode-aware music picker and a persistent player.
- Independent explicit defaults for Focus, Relax and Meditation; star any compatible music without changing playback. Trying a piece never overwrites the default.
- Relax and Meditation share the exact music catalog; selecting relaxing music during meditation preserves the mode, stopwatch and chimes.
- Keep music volume, background type/amount and gentle start/crossfade durations next to the picker. Remember background and music levels per mode.
- Add genuine original white noise alongside pink/brown noise, rain and ocean. Background changes neither restart music nor start a paused session.
- Move tone controls, imports, saved mixes, history, CLI help and credits into optional sheets. Remember sound shaping per music and mode.
- Preserve existing data, music, private imports, CLI IDs, gentle-start behavior and daily accounting. Keep legacy UI command routes as aliases.
- Add catalog/default/migration unit tests and a muted native listening-flow integration suite.

## 1.9.4 — Fresh selection after pause

- Retain audio-thread entrance measurements so fade-in regressions can be verified even if status polling is delayed.
- Upload release files to the exact unpublished release ID, with size and SHA-256 verification before publication.

- Selecting a composition, mode, saved mix or solo library sound while paused starts that music from its beginning with the full gentle entrance. No previous scene fades back in.
- The ordinary Play button resumes the existing music with its shorter resume fade, including a paused crossfade.
- Discard pending preparation and both old crossfade scenes on explicit fresh selection. Rewind recorded layers explicitly.
- Keep the session stopwatch, daily activity, user volume and chimes independent of musical restarts.
- Keep live scene-to-scene crossfades unchanged.

## 1.9.3 — Independent local sound studio

- Remove the unused external streaming player, catalog, UI routes and CLI commands.
- Remove comparison-service branding from the interface, current and archived documentation, and release copy.
- Report standalone export provenance as `audio_origin: local_generation`.
- Preserve the music engine, gentle starts, scene transitions, daily activity and meditation settings.

## 1.9.2 — Gentle start

- Start local music with an adjustable eight-second fade from silence; resume over up to two seconds.
- Wait until the generated scene is ready before advancing the entrance envelope.
- Apply the same gentle curve to recorded layers and personal imports without overriding volume changes.
- Keep ongoing scene crossfades, meditation chimes, stored volumes and daily activity independent.
- Expose `startFadeSeconds` in Settings and the CLI, with backward-compatible defaults.
- Add regression tests for delayed preparation, pause/resume, new sessions, live gain changes and scene switching.

## 1.9.1 — Simpler navigation

- Remove the external streams entry from the sidebar.

## 1.9.0 — English interface and correct daily activity

- Translate native UI, menu-bar player, profiles, accessibility labels, tooltips, alerts, streaming-player wrapper, update flow and CLI-facing errors into English.
- Keep stored profile IDs, CLI commands, asset filenames, custom mix names and personal imports unchanged.
- Replace the stale accumulated-session Today calculation with a separate activity ledger, clipped to local calendar days and unioned to avoid overlap/double counting.
- Exclude pauses and offline time; retain daily activity when resetting the stopwatch. Refresh after midnight even when paused, using DST-aware day boundaries.
- Migrate old history without deleting records. Pre-1.9 daily allocations remain explicitly approximate because pause times were not saved.
- Add deterministic regression tests, a native daily-accounting integration test and a source-language check.
- Refresh the English README, audition links, current guides, privacy information, contributor guide and bug-report template. Retain earlier French research in a clearly marked historical archive.
- Preserve the existing music engine, transitions, mixes, volume and meditation chimes.

## 1.8.0 — Long-form music and transitions

Seven featured compositions, a long-form phrase planner and a bounded two-scene crossfade mixer. Added Amber, Canopy and Meridian; developed the four earlier pieces.

## 1.7.0 — Signature compositions

Introduced Slipstream, Filigree, Confluence and Sanctuary, recorded soft piano and an original synthesized wordless choir.

## 1.6.0 — Acoustic orchestra

Integrated a pinned CC0 instrument bank and four orchestral arrangements.

## 1.5.0 — Public releases

Public GitHub source, universal macOS builds and opt-in SHA-256-verified update downloads.