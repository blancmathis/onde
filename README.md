# Onde

**Free, open-source music for focus, relaxation and meditation. Native to your Mac.**

Choose a mode, pick your music, and make it yours. Continuously generated audio, optional background noise and gentle meditation chimes, all on one screen. Runs locally, with a JSON CLI for humans and agents. No account or subscription.

[**Download for macOS**](https://github.com/blancmathis/onde/releases/latest/download/Onde-macOS-universal.zip) · [Listen first](#listen-first) · [Documentation](Documentation/README.md) · [Releases](https://github.com/blancmathis/onde/releases) · [Report a bug](https://github.com/blancmathis/onde/issues/new?template=bug_report.yml)

**Requires macOS 14 or later.** The download is universal: Apple Silicon and Intel. Community builds are ad-hoc signed and **not notarized by Apple**, so macOS may require explicit approval to open the app. Onde does not change Gatekeeper or your security settings.

## A simpler way to listen

**Focus, Relax, Meditation. One screen, no library to figure out.** Each mode
shows its default music. Click a card to listen now; use its star to set what
starts next time. Meditation uses the same music as Relax, with its own default,
stopwatch and chimes.

Music level, optional white/pink/brown noise or nature sounds, gentle starts and
crossfades stay beside the picker. Detailed instrument controls, imports, saved
mixes and other tools are available when needed, not in the way of listening.
All existing user data and audio profiles are preserved.

[Listening guide](Documentation/LISTENING.md)

## What it does

- **Focus, Relax and Meditation:** choose a mode and keep the musical style you like.
- **Long-form generation:** seven featured compositions, plus earlier soundscapes. Eight-bar phrases, gradual harmonic movement and slower orchestration changes, rather than a whole track on repeat.
- **Gentle start:** music fades in over eight seconds, with a shorter resume fade. Adjustable in Settings or through `onde settings startFadeSeconds 8`; volume and chimes are preserved.
- **Smooth scene changes:** prepare the next scene off the audio thread, then crossfade at a bar boundary. Adjustable from 2 to 30 seconds. This is a musical handover, not DJ beatmatching between different tempos.
- **Make the sound your own:** control bass, impact, note density, warmth, instrument sections, piano and wordless vocals. Save mixes and import personal audio.
- **Open-ended meditation:** a count-up stopwatch. By default, a gentle glass chime at 10, 20 and 30 minutes, then no more reminders. The session continues. Chime times and levels are configurable.
- **Daily activity that actually resets:** count running-session intervals within your current local day, excluding pauses. A session can span midnight without its full duration being added to Today.
- **Agent-friendly control:** the UI and CLI share one state through a private UNIX socket. Commands return JSON; `watch` streams NDJSON.

No telemetry or cloud audio engine. The optional update checker contacts GitHub. Sound playback does not use external streaming players.

## Listen first

These are continuous twelve-minute renders of the same engine and defaults used in the app. In-app generation does not restart these files. The English display names changed in 1.9; **CLI IDs and asset filenames remain stable**.

| Soundscape | Character | Audition |
|---|---|---|
| **Amber** (`ambre`) | Electric keys, soft bass, recorded piano responses · 82 BPM | [12 minutes](https://github.com/blancmathis/onde/releases/latest/download/ambre-12min.m4a) |
| **Canopy** (`canopee`) | Synthesized wooden resonances, acoustic harp and low strings · 94 BPM | [12 minutes](https://github.com/blancmathis/onde/releases/latest/download/canopee-12min.m4a) |
| **Meridian** (`meridien`) | Minimal house, driving bass and steady offbeats · 108 BPM | [12 minutes](https://github.com/blancmathis/onde/releases/latest/download/meridien-12min.m4a) |
| **Slipstream** (`sillage`) | Deep electronic bass and developing dark motifs · 92 BPM | [12 minutes](https://github.com/blancmathis/onde/releases/latest/download/sillage-12min.m4a) |
| **Filigree** (`filigrane`) | Recorded soft piano with a steady left-hand anchor · 78 BPM | [12 minutes](https://github.com/blancmathis/onde/releases/latest/download/filigrane-12min.m4a) |
| **Confluence** (`confluence`) | Hybrid orchestra, rhythmic cellos and sustained strings · 88 BPM | [12 minutes](https://github.com/blancmathis/onde/releases/latest/download/confluence-12min.m4a) |
| **Sanctuary** (`sanctuaire`) | Synthesized, wordless vowel choir, harp and steady bass · 86 BPM | [12 minutes](https://github.com/blancmathis/onde/releases/latest/download/sanctuaire-12min.m4a) |

[Hear an Amber → Sanctuary transition](https://github.com/blancmathis/onde/releases/latest/download/transition-ambre-sanctuaire.m4a).

The music is **evidence-informed, not clinically validated**. These compositions are not proven to improve everyone's concentration or to match another product's effects. Tempo, key and frequency balance are artistic choices, not a medical protocol. See [music, research and limitations](Documentation/MUSIC.md).

## Install

1. Download and unzip `Onde-macOS-universal.zip` from the link above.
2. Move `Onde.app` into `~/Applications` or `/Applications` and open it.
3. Choose **Focus**, **Relax** or **Meditation**, then select music and adjust the volume.

The acoustic bank is bundled. No plugins, audio accounts, API keys or instrument downloads are required during a session. Closing the main window leaves the menu-bar player running. Pause before leaving; the daily total measures **running session time**, not verified human attention.

### Optional CLI shortcut

The CLI is inside the app. It works without a shell installation:

```sh
~/Applications/Onde.app/Contents/MacOS/ondectl schema
~/Applications/Onde.app/Contents/MacOS/ondectl generate profile sanctuaire --launch
```

For `/Applications`, use that path instead. The optional source installer creates `~/.local/bin/onde` without editing your shell profile. The commands below assume that shortcut exists.

## CLI examples

```sh
~/.local/bin/onde generate profiles
~/.local/bin/onde generate profile meridien --launch
~/.local/bin/onde generate set bass 0.8
~/.local/bin/onde generate transition 10
~/.local/bin/onde mix save 'My focus mix'
~/.local/bin/onde pause
~/.local/bin/onde play
~/.local/bin/onde meditate
~/.local/bin/onde timer markers 10,20,30
~/.local/bin/onde status
~/.local/bin/onde watch
~/.local/bin/onde schema
```

`status` includes `today_seconds`, `today_time_zone` and the independent `elapsed_seconds` stopwatch. No TCP listener is opened. IPC requests do not execute shell code. `--launch` explicitly opens the app when necessary; without it, the CLI does not open the app implicitly.

Standalone WAV export, without the app running:

```sh
~/Applications/Onde.app/Contents/MacOS/ondectl generate render sanctuaire \
  "$HOME/Desktop/Sanctuary.wav" --minutes 30
```

The exporter uses a fresh instance of the same render core, writes a JSON provenance sidecar and refuses to overwrite an existing destination. To reproduce a customized mix, supply its settings explicitly. [Full CLI guide](Documentation/AGENTS.md).

## Updates

A successful push to `main` runs tests, builds Intel and Apple Silicon executables and publishes a complete release. The app can check the public GitHub release API at launch, when returning to the app, and approximately every five minutes. A new build shows a **Download** button, even if its semantic version is unchanged.

Downloads are size-checked and SHA-256-verified, then saved to Downloads. **Installation is manual:** quit Onde and replace the app. Your settings, history and imported audio live outside the app bundle. Automatic checks can be disabled in **Updates**. GitHub receives ordinary network metadata, not listening history or imports.

## Daily time: what changed in 1.9

Previously, Today incorrectly added the entire current session, including hours from yesterday. The new ledger records only active intervals, splits them at local calendar-day boundaries, and merges overlaps so duplicated records cannot inflate a day. Pauses and time while the app is closed are not counted. Resetting the session stopwatch does not erase daily activity.

Calendar days use the current time zone, including daylight-saving transitions. An actual day can be 23 or 25 hours; no fixed 24-hour clamp hides errors. Existing history is preserved. **Pre-1.9 day allocations are estimates**, because those files contain no exact pause intervals. New activity is checkpointed every 15 seconds; abrupt termination may lose the last unflushed interval, but never invents time while the app was closed. [Implementation and tests](Documentation/DAILY-ACTIVITY.md).

## Build from source

Requires macOS 14+, a Swift 5.9+ toolchain/Apple command-line tools, and Python 3. GitHub release builds use Xcode on macOS runners.

```sh
git clone https://github.com/blancmathis/onde.git
cd onde
bash Tools/prepare_orchestra.sh
ONDE_SKIP_DOWNLOADS=1 ONDE_ORIGINALS_ONLY=1 bash Tools/build.sh
bash Tools/install.sh
open ~/Applications/Onde.app
```

Preparing the bank downloads pinned, checksum-verified CC0 notes. The build generates the original sound beds and chime locally. The flags above exclude optional third-party composition downloads, not the acoustic CC0 bank.

```sh
swift test -c release -j 3
python3 Tools/check_english.py
python3 Tools/daily_activity_integration_test.py
python3 Tools/generative_integration_test.py
python3 Tools/profile_integration_test.py
python3 Tools/transition_integration_test.py
```

Integration tests require an interactive macOS session. They use muted output and isolated temporary profiles. `ONDE_HOME` selects an isolated local profile and disables automatic update checks in test instances. Do not point tests at your personal library.

## Privacy and licensing

User data: `~/Library/Application Support/Onde/`. Imports, mixes and history are not automatically uploaded. The repository and release bundle contain no personal imports or commercial streaming recordings. Playback is local; there is no embedded streaming player.

**Code: MIT. Original generated audio and VSCO 2 CE instrument bank: CC0-1.0.** Optional CC BY tracks retain their separate credits. [Third-party notices](THIRD_PARTY_NOTICES.md) · [Privacy](Documentation/PRIVACY.md) · [Contributing](CONTRIBUTING.md).

## Architecture

`OndeDSP`: preallocated C11 synthesis, acoustic-note sampler, vowel choir, phrase planner and two-scene crossfade mixer. `OndeCore`: settings, daily accounting, renderers, IPC and release verification. `OndeApp`: SwiftUI and Core Audio. `onde`: native CLI. Music generation works offline and does not require machine-learning weights.

Reports about audibility, repetition, transitions, accessibility and bugs are welcome. Include the profile ID, version, macOS version and steps to reproduce—never private audio or account credentials.
