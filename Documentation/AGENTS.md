# Onde: agent and CLI guide

Onde exposes one application state through its native interface and a JSON-lines UNIX socket. The CLI is bundled at `Onde.app/Contents/MacOS/ondectl`. An optional `~/.local/bin/onde` symlink can be created by `Tools/install.sh`. Examples use that shortcut.

## Start here

```sh
~/.local/bin/onde schema
~/.local/bin/onde status
~/.local/bin/onde generate profiles
~/.local/bin/onde sounds
```

Every response is JSON with `ok` and `result`, or `error` containing `code` and `message`. Exit code 0 indicates success, 2 an invalid/failed operation, 3 an app that is not running. `schema`, profile listing and offline renders do not need a running app. `--launch` explicitly opens the app for other commands. No implicit launch occurs otherwise.

The IPC socket is owner-only under `~/Library/Application Support/Onde/control.sock`. It is not a TCP service. Requests do not execute shell commands. `onde call '{"command":"status"}'` sends a structured request. `onde watch` emits NDJSON snapshots until stopped.

## Modes, playback and layers

```sh
onde focus --launch
onde relax
onde meditate
onde pause
onde play
onde stop
onde sound rain on --volume 0.25
onde sound aube off
onde solo piano
onde volume 0.4
onde silence
```

`silence` disables sound layers, including the generator, but leaves the active session stopwatch and meditation chimes running. Master volume zero also silences chimes. Do not raise a user's volume unexpectedly. Closing the main window does not end playback.

## Generative compositions

English display names changed in 1.9; IDs did not:

| Display name | Stable ID |
|---|---|
| Amber | `ambre` |
| Canopy | `canopee` |
| Meridian | `meridien` |
| Slipstream | `sillage` |
| Filigree | `filigrane` |
| Confluence | `confluence` |
| Sanctuary | `sanctuaire` |

Use `generate profiles` for all current profiles and exact default settings. Do not derive an ID by lowercasing an English title.

```sh
onde generate profile sanctuaire --launch
onde generate status
onde generate set bass 0.8
onde generate set vocals 0.5
onde generate set piano 0.7
onde generate set strings 0.8
onde generate set brass 0.4
onde generate transition 10
onde generate seed 42
onde mix save 'My soundscape'
onde mix load 'My soundscape'
```

Controls are normally 0–1. Tempo is 40–120 BPM; `settleMinutes` is 0–120; `composition` is an integer 0–7. Use `schema` and profile data as the source of truth. Values must be finite; booleans are not numbers. Seeds are exact nonnegative integers up to 2^53−1.

A profile selection prepares the next scene, waits for a bar boundary and crossfades. A successful request means accepted, not necessarily already audible. Poll `generate status` and its `transition` state, `running`, `rendered_seconds`, source/target profiles and `last_error`. Rapid selection resolves to the last request. Switching Focus pieces preserves the session stopwatch. A mode change starts a new session.

`generate defaults` restores that mode's sound parameters, not global volume or chimes. Custom mixes preserve generator configuration. Keep user-saved names and imports unchanged.

## Meditation

```sh
onde timer markers 10,20,30
onde settings chimeVolume 0.2
onde settings chimesEnabled false
onde chime preview
onde timer reset
```

Markers are absolute elapsed-minute positions, not repeating intervals. Defaults are 10, 20 and 30 minutes. After the last one, the stopwatch and soundscape continue. Empty markers disable reminders. Pause time is excluded. Reset permits a new set of markers, but does not erase the daily total.

## Daily accounting

`status` exposes `today_seconds`, `today_time_zone`, `daily_history_estimated`, and the independent `elapsed_seconds`. Today uses active intervals in the current local day, not the entire stopwatch. Historical estimates reflect pre-1.9 data lacking pause intervals. Do not treat session time as a measure of attention. [Details](DAILY-ACTIVITY.md).

## Offline export

```sh
onde generate render sanctuaire "$HOME/Desktop/Sanctuary.wav" --minutes 30
onde generate render sillage "$HOME/Desktop/Slipstream.wav" --seconds 120 --seed 42 --settings '{"bass":0.7}'
onde generate transition-render ambre sanctuaire "$HOME/Desktop/Transition.wav" --seconds 70 --at 25 --fade 10
```

The same DSP and bundled bank are used. Renders start fresh from the selected defaults unless custom settings are supplied. They do not implicitly read the active UI mix. WAV exports support up to three hours per file; live generation has no track-length limit. Existing destinations are never overwritten. Provenance sidecars document settings and sources.

## Import, navigation and updates

```sh
onde import '/absolute/path/audio.wav'
onde ui page generative
onde ui page history
onde ui page updates
onde ui show
onde update check --wait
onde update download --wait
onde update automatic off
```

Import copies audio into the private local library. Never add a user's imports or state file to the public repository. Update downloads are verified and saved but never auto-installed. Do not disable Gatekeeper or other protections.

## Testing and source development

Use temporary `ONDE_HOME` directories for integration tests. They disable automatic update checking in test instances. Keep output muted. All protocol IDs remain ASCII and stable; English labels are presentation, not a data migration. Do not change musical parameters as a side effect of translation or accounting fixes.

## Gentle start (1.9.2)

`onde settings startFadeSeconds N` sets the next playback entrance (0–20 seconds, default 8). Resume uses `min(2,N)` seconds. This is a preference, not a generative DSP parameter. Read `status.preferences.startFadeSeconds`, `generator.entrance` and `playback.recorded_layers` for configuration/progress. Parameter edits do not restart the envelope; profile changes use the existing crossfade. See [Gentle start](GENTLE-START.md).

### Playback selection versus resume

`generate profile ID`, mode selection, `mix load` and `solo ID` select music.
While paused, the next playback starts a fresh musical timeline with the full
`startFadeSeconds` entrance, without playing an old scene first. Re-selecting
the same profile restarts it too. `solo` still preserves paused/running state;
use `play` afterwards to hear it. Plain `play` without a selection resumes.
A live profile change still crossfades. Music restarts do not reset daily activity
or a same-mode stopwatch. Recorded layer status includes `position_seconds`.
