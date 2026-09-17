# Contributing

Use English for new interface text, user-facing errors, documentation and issue reports. Keep native accessibility labels clear and date formatting consistent with the English UI. Do not change stable CLI IDs or filenames merely to change a display name.

## Build and test

Follow [the README](README.md#build-from-source). Tests require the pinned acoustic bank for acoustic rendering. Run unit tests and `python3 Tools/check_english.py`. Native integration tests require an interactive macOS session and always use their own `ONDE_HOME` with muted audio. Never test against a user's personal profile.

Changes to time accounting must cover midnight, pause, stop, reset, restart, clock adjustment and DST. The unlimited stopwatch, meditation chimes and daily total are separate concepts. Do not fix a day bug by clamping to 24 hours, erasing history or resetting a running meditation.

Changes to audio must retain real-time safety: no allocation, disk/network access or blocking locks in the render callback. Test the same engine that ships. Avoid claims of optimal cognition or perceptual equivalence unsupported by actual listener trials.

## Pull requests and releases

Open a branch and describe behavior changes, test results, limitations and any new asset licenses. Do not commit private imports, state files, health/computer-activity data, credentials, generated builds or unlicensed reference recordings.

Pushes to this repository's main branch build a universal community release after tests pass. Forks must set their own update repository intentionally; do not distribute an app that silently fetches another project's binaries. Preserve the release asset name and tag/digest format expected by `UpdatePolicy`.

The app currently uses ad-hoc signing, not Apple notarization. Do not bypass security controls in installation scripts. Report vulnerabilities privately to the maintainer instead of publishing sensitive exploit or credential material in issues.
