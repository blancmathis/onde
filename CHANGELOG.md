# Changelog

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
